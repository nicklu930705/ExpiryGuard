import SwiftUI

/// 日期計算工具
enum DateHelpers {
    
    /// 計算從今天到目標日期的天數差
    static func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: today, to: target)
        return components.day ?? 0
    }
    
    /// 判斷效期狀態
    static func expiryStatus(for date: Date) -> ExpiryStatus {
        let days = daysUntil(date)
        if days < 0 { return .expired }
        if days <= 3 { return .urgent }
        return .safe
    }
    
    /// 產生狀態標籤文字（例如「過期 1 天」「剩 2 天」「今天到期」）
    static func statusLabel(for date: Date) -> String {
        let days = daysUntil(date)
        if days < 0 {
            return "過期 \(abs(days)) 天"
        } else if days == 0 {
            return "今天到期"
        } else {
            return "剩 \(days) 天"
        }
    }
    
    /// 從今天加上指定天數
    static func addDays(_ days: Int, to date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
    
    /// 從今天加上指定月數
    static func addMonths(_ months: Int, to date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    }
    
    /// 格式化日期為 yyyy-MM-dd
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 格式化日期為中文短格式（9月5日）
    static func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
