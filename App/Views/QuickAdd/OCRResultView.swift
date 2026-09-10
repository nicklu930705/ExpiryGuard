import SwiftUI

// MARK: - OCRResultView
struct OCRResultView: View {
    let image: UIImage
    let service: OCRService
    var onDateSelected: (Date) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Text("效期辨識結果")
                        .font(.headline)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Image Preview
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        
                        // Status: Processing
                        if service.isProcessing {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.3)
                                Text("正在分析包裝與效期...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 30)
                        }
                        // Status: Date Found
                        else if let date = service.recognizedDate {
                            resultCard(date: date)
                        }
                        // Status: Not Found
                        else {
                            failureCard
                        }
                        
                        // Error message if any
                        if let error = service.errorMessage {
                            Text(error)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Result Card
    @ViewBuilder
    private func resultCard(date: Date) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.green)
                Text("辨識出有效日期（到期日）")
            }
            .font(.headline)
            .foregroundColor(.secondary)
            
            Text(date.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            
            if let reason = service.recognizedReason {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(reason.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "🔍 ", with: "").replacingOccurrences(of: "⚠️ ", with: ""))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // 偵測到品名提示
            if let detectedName = service.suggestedProductName, !detectedName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.blue)
                    Text("偵測品名：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(detectedName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // 偵測到製造日期提示
            if let mfg = service.recognizedMfgDate, mfg != date {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🏭 偵測到的製造日期")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mfg.formatted(date: .numeric, time: .omitted))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button("改用此日期") {
                        onDateSelected(mfg)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                }
                .padding(12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // 使用按鈕
            Button {
                onDateSelected(date)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("使用此日期")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Failure Card
    @ViewBuilder
    private var failureCard: some View {
        VStack(spacing: 16) {
            Text("未能辨識到日期")
                .foregroundColor(.orange)
                .font(.headline)
            
            Text("由於包裝反光、點陣字體或角度傾斜，未能精準讀取到效期。您可以手動輸入日期，或稍微調整角度重拍一張。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                onDismiss()
            } label: {
                Text("手動輸入日期")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
