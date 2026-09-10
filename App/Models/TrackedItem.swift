import Foundation
import SwiftData

/// 追蹤中的物品
@Model
final class TrackedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String  // ItemCategory.rawValue
    var expiryDate: Date
    var createdAt: Date
    
    // Reminders
    var reminder1Days: Int?
    var reminder2Days: Int?
    var reminderTime: Date?
    
    init(name: String, category: ItemCategory, expiryDate: Date) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.expiryDate = expiryDate
        self.createdAt = .now
    }
    
    // MARK: - Computed Properties
    
    @Transient
    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .refrigerated }
        set { categoryRaw = newValue.rawValue }
    }
    
    @Transient
    var daysRemaining: Int {
        DateHelpers.daysUntil(expiryDate)
    }
    
    @Transient
    var status: ExpiryStatus {
        DateHelpers.expiryStatus(for: expiryDate)
    }
    
    @Transient
    var statusLabel: String {
        DateHelpers.statusLabel(for: expiryDate)
    }
}
