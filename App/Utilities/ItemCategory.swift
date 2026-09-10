import SwiftUI

/// 物品分類
struct ItemCategory: Codable, Identifiable, Hashable {
    var id: String { name }
    let emoji: String
    let name: String
    
    init(emoji: String, name: String) {
        self.emoji = emoji
        self.name = name
    }
    
    var label: String { "\(emoji) \(name)" }
    
    var sfSymbol: String {
        switch name {
        case "冷藏食品": return "snowflake"
        case "生鮮肉品": return "fork.knife"
        case "蔬菜水果": return "leaf.fill"
        case "冷凍食品": return "cube.fill"
        case "飲料": return "cup.and.saucer.fill"
        case "零食乾糧": return "bag.fill"
        case "藥品保健": return "cross.case.fill"
        case "美妝保養": return "sparkles"
        default: return "tag.fill"
        }
    }
    
    // Default categories
    static let refrigerated = ItemCategory(emoji: "🥛", name: "冷藏食品")
    static let meat         = ItemCategory(emoji: "🥩", name: "生鮮肉品")
    static let veggies      = ItemCategory(emoji: "🥬", name: "蔬菜水果")
    static let frozen       = ItemCategory(emoji: "🧊", name: "冷凍食品")
    static let drinks       = ItemCategory(emoji: "🥤", name: "飲料")
    static let snacks       = ItemCategory(emoji: "🍪", name: "零食乾糧")
    static let medicine     = ItemCategory(emoji: "💊", name: "藥品保健")
    static let beauty       = ItemCategory(emoji: "✨", name: "美妝保養")
    
    static var defaultCategories: [ItemCategory] {
        [.refrigerated, .meat, .veggies, .frozen, .drinks, .snacks, .medicine, .beauty]
    }
    
    // MARK: - SwiftData Persistence Helpers
    
    var rawValue: String {
        "\(emoji)|\(name)"
    }
    
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", maxSplits: 1)
        if parts.count == 2 {
            self.emoji = String(parts[0])
            self.name = String(parts[1])
        } else {
            // Backward compatibility
            if let found = ItemCategory.defaultCategories.first(where: { $0.name == rawValue }) {
                self = found
            } else {
                self.emoji = "📦"
                self.name = rawValue
            }
        }
    }
}

/// 效期狀態
enum ExpiryStatus {
    case expired  // 已過期
    case urgent   // 3 天內到期
    case safe     // 安全
    
    var color: Color {
        switch self {
        case .expired: return .red
        case .urgent:  return .orange
        case .safe:    return Color(.systemGreen)
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .expired: return Color.red.opacity(0.1)
        case .urgent:  return Color.orange.opacity(0.1)
        case .safe:    return Color.green.opacity(0.1)
        }
    }
}

/// 歸檔原因
enum ArchiveReason: String, Codable {
    case consumed = "consumed"  // 已吃完/用完
    case wasted   = "wasted"    // 過期丟棄
}

/// 自訂分類持久化管理
@MainActor
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()
    
    @Published var customCategories: [ItemCategory] = []
    
    private let storageKey = "custom_categories_v1"
    
    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
    }
    
    init() {
        loadCategories()
    }
    
    func loadCategories() {
        let decoder = JSONDecoder()
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? decoder.decode([ItemCategory].self, from: data) {
            self.customCategories = decoded
            return
        }
        if let standardData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([ItemCategory].self, from: standardData) {
            self.customCategories = decoded
        }
    }
    
    func addCategory(_ category: ItemCategory) {
        if let index = customCategories.firstIndex(where: { $0.name == category.name }) {
            customCategories[index] = category
        } else {
            customCategories.append(category)
        }
        saveCategories()
    }
    
    func deleteCategory(_ category: ItemCategory) {
        customCategories.removeAll(where: { $0.name == category.name })
        saveCategories()
    }
    
    private func saveCategories() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(customCategories) {
            userDefaults.set(data, forKey: storageKey)
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

