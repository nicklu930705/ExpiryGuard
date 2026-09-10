import SwiftUI
import SwiftData

struct EditReminderSheet: View {
    let item: TrackedItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var reminder1Days: Int
    @State private var reminder2Days: Int
    @State private var reminderTime: Date
    
    let reminderOptions = [
        (-1, "不提醒"),
        (0, "當天"),
        (1, "1 天前"),
        (3, "3 天前"),
        (7, "7 天前"),
        (14, "14 天前"),
        (30, "30 天前")
    ]
    
    init(item: TrackedItem) {
        self.item = item
        // Initialize state from item properties, with defaults if they were created before this update
        _reminder1Days = State(initialValue: item.reminder1Days ?? 1)
        _reminder2Days = State(initialValue: item.reminder2Days ?? -1)
        _reminderTime = State(initialValue: item.reminderTime ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("物品資訊")) {
                    HStack {
                        Text("名稱")
                        Spacer()
                        Text(item.name).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("分類")
                        Spacer()
                        Text("\(item.category.emoji) \(item.category.name)").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("到期日")
                        Spacer()
                        Text(DateHelpers.formatDate(item.expiryDate)).foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("提醒設定")) {
                    DatePicker("提醒時間", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    
                    Picker("第一提醒", selection: $reminder1Days) {
                        ForEach(reminderOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                    
                    Picker("第二提醒", selection: $reminder2Days) {
                        ForEach(reminderOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                }
            }
            .navigationTitle("編輯提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        save()
                    }
                }
            }
        }
    }
    
    private func save() {
        // Update item properties
        item.reminder1Days = reminder1Days
        item.reminder2Days = reminder2Days
        item.reminderTime = reminderTime
        
        try? item.modelContext?.save()
        
        let validReminders = [reminder1Days, reminder2Days].filter { $0 >= 0 }
        
        // Re-schedule notifications
        Task {
            await NotificationService.shared.scheduleExpiryReminders(
                itemID: item.id,
                itemName: item.name,
                expiryDate: item.expiryDate,
                reminderDays: validReminders,
                reminderTime: reminderTime
            )
        }
        
        dismiss()
    }
}
