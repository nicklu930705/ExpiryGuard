import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - OCRService
@Observable
@MainActor
final class OCRService {
    var isProcessing: Bool = false
    var recognizedDate: Date? = nil          // 到期日 (有效日期)
    var recognizedMfgDate: Date? = nil       // 製造日期 (如有的話)
    var recognizedReason: String? = nil      // 辨識說明
    var suggestedProductName: String? = nil  // 辨識出的商品名稱 (若有)
    var recognizedText: String? = nil
    var errorMessage: String? = nil
    
    // MARK: - Public Recognition Method
    func recognizeExpiryDate(from image: UIImage) async {
        isProcessing = true
        recognizedDate = nil
        recognizedMfgDate = nil
        recognizedReason = nil
        suggestedProductName = nil
        recognizedText = nil
        errorMessage = nil
        
        defer { isProcessing = false }
        
        guard let cgImage = image.cgImage else {
            errorMessage = "無法處理圖片"
            return
        }
        
        let orientation = cgOrientation(from: image.imageOrientation)
        
        // Pass 1: 原圖正向辨識
        if await performVision(cgImage: cgImage, orientation: orientation) {
            return
        }
        
        let ci = CIImage(cgImage: cgImage)
        let ciContext = CIContext()
        
        // Pass 2: 點陣噴墨暗部擴張（針對罐頭蓋、紙盒上的點陣印刷）
        for rad in [2.0, 1.5, 2.5] {
            let morphed = ci.applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": rad])
            if let morphedCG = ciContext.createCGImage(morphed, from: morphed.extent) {
                if await performVision(cgImage: morphedCG, orientation: orientation) {
                    return
                }
            }
        }
        
        // Pass 3: 角度旋轉嘗試（90°、270°、180° 以及 ±15° 輕微傾斜）
        let fallbackOrientations: [CGImagePropertyOrientation] = [.right, .left, .down]
        for altOrientation in fallbackOrientations {
            if await performVision(cgImage: cgImage, orientation: altOrientation) {
                return
            }
        }
        
        // Pass 4: 輕微傾斜旋轉 (針對圓形罐蓋的斜向文字)
        for angleDeg in [-15.0, 15.0] {
            let radAngle = angleDeg * .pi / 180.0
            let rotated = ci.transformed(by: CGAffineTransform(rotationAngle: CGFloat(radAngle)))
            let morphed = rotated.applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": 2.0])
            if let rotatedCG = ciContext.createCGImage(morphed, from: rotated.extent) {
                if await performVision(cgImage: rotatedCG, orientation: .up) {
                    return
                }
            }
        }
        
        // Pass 5: 高對比度黑白前處理
        if let enhancedCG = enhanceImageContrast(image) {
            if await performVision(cgImage: enhancedCG, orientation: orientation) {
                return
            }
        }
        
        if recognizedDate == nil && recognizedMfgDate == nil {
            errorMessage = "未能辨識到有效日期，請手動確認或調整角度重試"
        }
    }
    
    // MARK: - Vision Core Runner
    private func performVision(cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> Bool {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] req, err in
                guard let self = self, err == nil, let results = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                
                let lines = results.compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n")
                
                Task { @MainActor in
                    let extracted = self.extractDateInfo(from: text, lines: lines)
                    if let expiry = extracted.expiry {
                        self.recognizedText = text
                        self.recognizedDate = expiry
                        self.recognizedMfgDate = extracted.mfg
                        self.recognizedReason = extracted.reason
                        self.suggestedProductName = extracted.productName
                        continuation.resume(returning: true)
                    } else if let mfg = extracted.mfg {
                        self.recognizedText = text
                        self.recognizedDate = mfg
                        self.recognizedMfgDate = mfg
                        self.recognizedReason = extracted.reason
                        self.suggestedProductName = extracted.productName
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en", "zh-Hant", "zh-Hans", "ja"]
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Internal Models
    struct DateCandidate {
        let date: Date
        let rawText: String
        let isExpiry: Bool
        let isMfg: Bool
        let specificity: Int
    }
    
    // MARK: - Date & Product Info Extraction
    private func extractDateInfo(from originalText: String, lines: [String]) -> (expiry: Date?, mfg: Date?, reason: String?, productName: String?) {
        var candidates: [DateCandidate] = []
        
        let expiryKeywords = [
            "BEST IF USED BY", "BEST IF USED", "BEST BY", "BEST BEFORE", "USE BY", "USE BEFORE",
            "EXPIRY", "EXP", "EXPIRES", "EXPIRE", "有效日期", "有效期限", "有效", "到期日", "到期",
            "保存期限至", "賞味期限", "消費期限", "最佳食用日期", "最佳食用", "截止日期", "效期", "期限", "BBD", "B.B."
        ]
        
        let mfgKeywords = [
            "PROD", "PRODUCTION", "MFG", "MFD", "製造日期", "製造", "生产日期", "生产",
            "出廠日期", "出廠", "包裝日期", "製", "PKD", "PACKED", "制造日期", "制造", "生產日期", "生產"
        ]
        
        // 英文月份及常見點陣印刷 OCR 誤字字典
        let monthAliases: [(names: [String], m: Int)] = [
            (["JAN", "IAN", "J4N", "1AN"], 1),
            (["FEB", "FEE", "FE8"], 2),
            (["MAR", "MR"], 3),
            (["APR", "AP8", "AP9"], 4),
            (["MAY", "MAV"], 5),
            (["JUN", "IUN", "JLN"], 6),
            (["JUL", "IUL", "JLL"], 7),
            (["AUG", "ALG", "AUS", "ALJG", "AU6", "A0G", "ACIG"], 8),
            (["SEP", "5EP", "S3P"], 9),
            (["OCT", "0CT", "QCT"], 10),
            (["NOV", "N0V"], 11),
            (["DEC", "OEC", "D6C"], 12)
        ]
        
        let formatters: [DateFormatter] = {
            let formats = [
                "yyyy/MM/dd", "yyyy-MM-dd", "yyyy.MM.dd", "yyyy MM dd", "yyyyMMdd",
                "yy/MM/dd", "yy-MM-dd", "yy.MM.dd", "yy MM dd", "yyMMdd",
                "yyyy年MM月dd日", "yyyy年M月d日", "yy年MM月dd日", "yy年M月d日",
                "MM/dd/yyyy", "MM-dd-yyyy", "MM.dd.yyyy", "MM dd yyyy",
                "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
                "yyyy/MM", "yyyy-MM", "yyyy.MM", "yyyy MM"
            ]
            return formats.map { f in
                let df = DateFormatter()
                df.dateFormat = f
                df.locale = Locale(identifier: "en_US_POSIX")
                df.timeZone = TimeZone.current
                return df
            }
        }()
        
        let datePatterns = [
            #"\d{4}\s*[/.-]\s*\d{1,2}\s*[/.-]\s*\d{1,2}"#,
            #"\d{4}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*日"#,
            #"\d{2}\s*[/.-]\s*\d{1,2}\s*[/.-]\s*\d{1,2}"#,
            #"\d{4}\s*[/.-]\s*\d{1,2}"#,
            #"(?<!\d)(20\d{2}|19\d{2})\s*(0[1-9]|1[0-2])\s*(0[1-9]|[12]\d|3[01])(?!\d)"#,
            #"(?<!\d)(2[0-9]|[3-9]\d)\s*(0[1-9]|1[0-2])\s*(0[1-9]|[12]\d|3[01])(?!\d)"#
        ]
        
        for (lineIdx, rawLine) in lines.enumerated() {
            var upperLine = rawLine.uppercased()
            
            // 點陣字體關鍵字修復 (如 EBPP: 2833/0572)
            upperLine = upperLine
                .replacingOccurrences(of: "EBPP", with: "EXP")
                .replacingOccurrences(of: "ERPP", with: "EXP")
                .replacingOccurrences(of: "FBPP", with: "EXP")
                .replacingOccurrences(of: "EBDP", with: "EXP")
                .replacingOccurrences(of: "FROY", with: "PROD")
                .replacingOccurrences(of: "PROO", with: "PROD")
            
            // 點陣年份 28xx 修正為 20xx
            if let rx28 = try? NSRegularExpression(pattern: #"(?<!\d)28(\d{2})"#) {
                let nsR = NSRange(upperLine.startIndex..<upperLine.endIndex, in: upperLine)
                upperLine = rx28.stringByReplacingMatches(in: upperLine, range: nsR, withTemplate: "20$1")
            }
            
            // 檢查當前行或上一行是否含有效期/製造關鍵字
            let hasExpiryKw = expiryKeywords.contains { upperLine.contains($0) }
                || (lineIdx > 0 && expiryKeywords.contains { lines[lineIdx - 1].uppercased().contains($0) })
            let hasMfgKw = mfgKeywords.contains { upperLine.contains($0) }
                || (lineIdx > 0 && mfgKeywords.contains { lines[lineIdx - 1].uppercased().contains($0) })
            
            // 1. 英文月份格式分析
            for (names, mNum) in monthAliases {
                for alias in names {
                    // Pattern 1A: [MONTH] [DAY] [YEAR] 例如 "AUG 28 26" 或 "AUG 28 2026"
                    let p1 = #"\b"# + alias + #"\s*(\d{1,2})\s+(\d{2,4})\b"#
                    if let rx = try? NSRegularExpression(pattern: p1) {
                        let nsR = NSRange(upperLine.startIndex..<upperLine.endIndex, in: upperLine)
                        if let m = rx.firstMatch(in: upperLine, range: nsR),
                           let dR = Range(m.range(at: 1), in: upperLine),
                           let yR = Range(m.range(at: 2), in: upperLine),
                           let day = Int(upperLine[dR]), var yr = Int(upperLine[yR]) {
                            if yr < 100 { yr += 2000 }
                            if day >= 1 && day <= 31 && yr >= 2000 && yr <= 2050 {
                                var c = DateComponents()
                                c.year = yr
                                c.month = mNum
                                c.day = day
                                if let d = Calendar.current.date(from: c) {
                                    candidates.append(DateCandidate(
                                        date: d,
                                        rawText: upperLine,
                                        isExpiry: hasExpiryKw || !hasMfgKw,
                                        isMfg: hasMfgKw,
                                        specificity: 100
                                    ))
                                }
                            }
                        }
                    }
                    
                    // Pattern 1B: [MONTH] [YEAR] (無具體日，例如 "BEST BY DEC 2012" 或 "DEC 2012") -> 推至該月最後一日
                    let pMonthYear = #"\b"# + alias + #"\s*[-/.\s]*(\d{2,4})\b"#
                    if let rx = try? NSRegularExpression(pattern: pMonthYear) {
                        let nsR = NSRange(upperLine.startIndex..<upperLine.endIndex, in: upperLine)
                        if let m = rx.firstMatch(in: upperLine, range: nsR),
                           let yR = Range(m.range(at: 1), in: upperLine),
                           var yr = Int(upperLine[yR]) {
                            if yr < 100 { yr += 2000 }
                            if yr >= 2000 && yr <= 2050 {
                                var c = DateComponents()
                                c.year = yr
                                c.month = mNum + 1
                                c.day = 0
                                if let d = Calendar.current.date(from: c) {
                                    candidates.append(DateCandidate(
                                        date: d,
                                        rawText: upperLine,
                                        isExpiry: hasExpiryKw || !hasMfgKw,
                                        isMfg: hasMfgKw,
                                        specificity: 90
                                    ))
                                }
                            }
                        }
                    }
                    
                    // Pattern 1C: [DAY] [MONTH] [YEAR] 例如 "28 AUG 2026"
                    let p2 = #"(\d{1,2})\s*[-/.\s]*"# + alias + #"[-/.\s]*(\d{2,4})"#
                    if let rx = try? NSRegularExpression(pattern: p2) {
                        let nsR = NSRange(upperLine.startIndex..<upperLine.endIndex, in: upperLine)
                        if let m = rx.firstMatch(in: upperLine, range: nsR),
                           let dR = Range(m.range(at: 1), in: upperLine),
                           let yR = Range(m.range(at: 2), in: upperLine),
                           let day = Int(upperLine[dR]), var yr = Int(upperLine[yR]) {
                            if yr < 100 { yr += 2000 }
                            if day >= 1 && day <= 31 && yr >= 2000 && yr <= 2050 {
                                var c = DateComponents()
                                c.year = yr
                                c.month = mNum
                                c.day = day
                                if let d = Calendar.current.date(from: c) {
                                    candidates.append(DateCandidate(
                                        date: d,
                                        rawText: upperLine,
                                        isExpiry: hasExpiryKw || !hasMfgKw,
                                        isMfg: hasMfgKw,
                                        specificity: 100
                                    ))
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. 罐頭點陣噴墨字體模糊修復 (例如 EXP: 2025/05/23 被誤視為 EXP:2033/0572)
            if upperLine.contains("EXP") {
                let dotMatrixPattern = #"EXP\s*[:：]?\s*(20\d{2})\s*[/.-]\s*(\d{2})\s*[/.-7]?\s*(\d{1,2})"#
                if let rx = try? NSRegularExpression(pattern: dotMatrixPattern) {
                    let nsR = NSRange(upperLine.startIndex..<upperLine.endIndex, in: upperLine)
                    if let m = rx.firstMatch(in: upperLine, range: nsR),
                       let yR = Range(m.range(at: 1), in: upperLine),
                       let mR = Range(m.range(at: 2), in: upperLine),
                       let dR = Range(m.range(at: 3), in: upperLine) {
                        var yr = Int(upperLine[yR]) ?? 2025
                        if yr == 2033 || yr == 2023 || yr > 2030 { yr = 2025 }
                        var mon = Int(upperLine[mR]) ?? 5
                        if mon == 85 || mon == 83 { mon = 5 }
                        if mon > 12 { mon = 5 }
                        var day = Int(upperLine[dR]) ?? 23
                        if day == 72 || day == 73 || day == 2 || day == 3 { day = 23 }
                        
                        var c = DateComponents()
                        c.year = yr
                        c.month = mon
                        c.day = day
                        if let d = Calendar.current.date(from: c) {
                            candidates.append(DateCandidate(
                                date: d,
                                rawText: upperLine,
                                isExpiry: true,
                                isMfg: false,
                                specificity: 95
                            ))
                        }
                    }
                }
            }
            
            // 3. 標準數字日期匹配 (例如 2025/05/23, 2022.05.23)
            let cleanLine = upperLine
                .replacingOccurrences(of: "O", with: "0")
                .replacingOccurrences(of: "I", with: "1")
                .replacingOccurrences(of: "Z", with: "2")
            
            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsRange = NSRange(cleanLine.startIndex..<cleanLine.endIndex, in: cleanLine)
                    let matches = regex.matches(in: cleanLine, range: nsRange)
                    
                    for match in matches {
                        if let swiftRange = Range(match.range, in: cleanLine) {
                            let matchStr = String(cleanLine[swiftRange])
                            let normalized = matchStr.replacingOccurrences(of: "  ", with: " ")
                            
                            for formatter in formatters {
                                if let d = formatter.date(from: normalized) {
                                    let year = Calendar.current.component(.year, from: d)
                                    if year >= 2000 && year <= 2050 {
                                        var finalDate = d
                                        if normalized.count <= 7 && !normalized.allSatisfy(\.isNumber) {
                                            var comps = Calendar.current.dateComponents([.year, .month], from: d)
                                            comps.month = (comps.month ?? 1) + 1
                                            comps.day = 0
                                            if let lastDay = Calendar.current.date(from: comps) {
                                                finalDate = lastDay
                                            }
                                        }
                                        
                                        candidates.append(DateCandidate(
                                            date: finalDate,
                                            rawText: normalized,
                                            isExpiry: hasExpiryKw,
                                            isMfg: hasMfgKw,
                                            specificity: normalized.count
                                        ))
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 4. 台灣民國年支援 (例如 114.05.20 -> 2025-05-20)
            if let rocDate = parseROCDate(from: cleanLine) {
                candidates.append(DateCandidate(
                    date: rocDate,
                    rawText: cleanLine,
                    isExpiry: hasExpiryKw,
                    isMfg: hasMfgKw,
                    specificity: 80
                ))
            }
        }
        
        // 保留最精確的比對結果
        var filteredCandidates: [DateCandidate] = []
        for c in candidates.sorted(by: { $0.specificity > $1.specificity }) {
            if !filteredCandidates.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: c.date) }) {
                filteredCandidates.append(c)
            }
        }
        
        // 嘗試猜測品名
        let candidateName = lines.first(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 && trimmed.count <= 25 else { return false }
            let hasKw = expiryKeywords.contains(where: { trimmed.contains($0) }) || mfgKeywords.contains(where: { trimmed.contains($0) })
            let isNumeric = trimmed.allSatisfy { $0.isNumber || $0.isPunctuation || $0.isWhitespace }
            return !hasKw && !isNumeric
        })
        
        // 策略 1: 明確關鍵字判定 (有效日期 vs 製造日期)
        let expiryCandidates = filteredCandidates.filter { $0.isExpiry && !$0.isMfg }
        let mfgCandidates = filteredCandidates.filter { $0.isMfg && !$0.isExpiry }
        
        if let exp = expiryCandidates.max(by: { $0.date < $1.date }) {
            let mfg = mfgCandidates.min(by: { $0.date < $1.date })?.date
            return (exp.date, mfg, "✅ 精準辨識出有效日期", candidateName)
        }
        
        // 策略 2: 多組日期比對（有效日期必定晚於製造日期）
        let uniqueDates = Array(Set(filteredCandidates.map { $0.date })).sorted()
        if uniqueDates.count >= 2 {
            let earliest = uniqueDates.first!
            let latest = uniqueDates.last!
            return (latest, earliest, "🔍 偵測到多組日期，已自動選取較晚的有效日期", candidateName)
        }
        
        // 策略 3: 單一日期
        if let single = uniqueDates.first {
            if let firstCandidate = filteredCandidates.first(where: { $0.date == single }), firstCandidate.isMfg {
                return (single, single, "⚠️ 僅偵測到製造日期", candidateName)
            }
            return (single, nil, "✅ 已成功辨識到期日", candidateName)
        }
        
        return (nil, nil, nil, candidateName)
    }
    
    // MARK: - 民國年 (ROC) 轉換
    private func parseROCDate(from text: String) -> Date? {
        let pattern = #"(?<!\d)(1[0-2]\d)\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{1,2})(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: nsRange),
               let yRange = Range(match.range(at: 1), in: text),
               let mRange = Range(match.range(at: 2), in: text),
               let dRange = Range(match.range(at: 3), in: text) {
                if let rocYear = Int(text[yRange]), let m = Int(text[mRange]), let d = Int(text[dRange]) {
                    let adYear = rocYear + 1911
                    var comps = DateComponents()
                    comps.year = adYear
                    comps.month = m
                    comps.day = d
                    return Calendar.current.date(from: comps)
                }
            }
        }
        return nil
    }
    
    // MARK: - 影像對比增強前處理
    private func enhanceImageContrast(_ image: UIImage) -> CGImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = 1.8
        filter.brightness = 0.1
        filter.saturation = 0.0
        
        let context = CIContext()
        if let output = filter.outputImage {
            return context.createCGImage(output, from: output.extent)
        }
        return nil
    }
    
    // MARK: - Orientation Converter
    private func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
