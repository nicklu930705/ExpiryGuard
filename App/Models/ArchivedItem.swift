import Foundation
import SwiftData

/// 已歸檔的物品（吃完或丟棄）
@Model
final class ArchivedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var expiryDate: Date
    var archivedAt: Date
    var reasonRaw: String  // ArchiveReason.rawValue
    
    init(name: String, category: ItemCategory, expiryDate: Date, reason: ArchiveReason) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.expiryDate = expiryDate
        self.archivedAt = .now
        self.reasonRaw = reason.rawValue
    }
    
    /// 從 TrackedItem 建立歸檔紀錄
    convenience init(from item: TrackedItem, reason: ArchiveReason) {
        self.init(
            name: item.name,
            category: item.category,
            expiryDate: item.expiryDate,
            reason: reason
        )
    }
    
    // MARK: - Computed Properties
    
    @Transient
    var category: ItemCategory {
        ItemCategory(rawValue: categoryRaw) ?? .refrigerated
    }
    
    @Transient
    var reason: ArchiveReason {
        ArchiveReason(rawValue: reasonRaw) ?? .consumed
    }
}
