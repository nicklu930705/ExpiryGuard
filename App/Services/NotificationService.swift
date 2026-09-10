import Foundation
import UserNotifications

/// 到期提醒通知管理
@Observable
@MainActor
final class NotificationService {
    
    static let shared = NotificationService()
    
    private(set) var isAuthorized: Bool = false
    
    // MARK: - Authorization
    
    /// 請求推播權限
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            self.isAuthorized = granted
            return granted
        } catch {
            print("[NotificationService] 請求權限失敗: \(error)")
            self.isAuthorized = false
            return false
        }
    }
    
    /// 檢查目前權限狀態
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = (settings.authorizationStatus == .authorized)
    }
    
    // MARK: - Schedule / Cancel
    
    /// 排程多個到期提醒通知（指定天數前，自訂時間）
    func scheduleExpiryReminders(itemID: UUID, itemName: String, expiryDate: Date, reminderDays: [Int], reminderTime: Date) async {
        if !isAuthorized {
            _ = await requestAuthorization()
            guard isAuthorized else { return }
        }
        
        // 先取消舊的
        cancelReminder(for: itemID)
        
        for (index, daysBefore) in reminderDays.enumerated() {
            guard let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: expiryDate) else {
                continue
            }
            
            // 將 reminderDate 的時間設定為使用者自訂的 reminderTime
            let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            var triggerComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
            triggerComponents.hour = timeComponents.hour
            triggerComponents.minute = timeComponents.minute
            
            // 確認排程時間大於現在
            guard let finalTriggerDate = Calendar.current.date(from: triggerComponents), finalTriggerDate > Date() else {
                continue
            }
            
            let content = UNMutableNotificationContent()
            if daysBefore == 0 {
                content.title = "🚨 今天到期！"
                content.body = "「\(itemName)」在今天到期，請盡快使用！"
            } else if daysBefore == 1 {
                content.title = "⚠️ 明天即將到期！"
                content.body = "「\(itemName)」將在明天到期，請盡快使用！"
            } else {
                content.title = "🗓️ 還有 \(daysBefore) 天到期"
                content.body = "「\(itemName)」即將過期，請注意！"
            }
            content.sound = .default
            content.userInfo = ["itemID": itemID.uuidString]
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerComponents,
                repeats: false
            )
            
            let identifier = "expiry-reminder-\(itemID.uuidString)-\(index)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("[NotificationService] 排程通知失敗: \(error)")
            }
        }
    }
    
    /// 取消特定物品的提醒
    func cancelReminder(for itemID: UUID) {
        let identifiers = [
            "expiry-reminder-\(itemID.uuidString)", // 舊版的相容
            "expiry-reminder-\(itemID.uuidString)-0",
            "expiry-reminder-\(itemID.uuidString)-1"
        ]
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// 取消所有提醒
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Private
    
    private func notificationID(for itemID: UUID) -> String {
        "expiry-reminder-\(itemID.uuidString)"
    }
}
