import SwiftUI
import WidgetKit
import AppIntents
import SwiftData

// MARK: - Widget Helpers

struct ItemCategory: Codable, Equatable {
    let emoji: String
    let name: String
    
    init(emoji: String, name: String) {
        self.emoji = emoji
        self.name = name
    }
    
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", maxSplits: 1)
        if parts.count == 2 {
            self.emoji = String(parts[0])
            self.name = String(parts[1])
        } else {
            switch rawValue {
            case "冷藏食品": self.emoji = "🥛"; self.name = rawValue
            case "生鮮肉品": self.emoji = "🥩"; self.name = rawValue
            case "蔬菜水果": self.emoji = "🥬"; self.name = rawValue
            case "冷凍食品": self.emoji = "🧊"; self.name = rawValue
            case "飲料": self.emoji = "🥤"; self.name = rawValue
            case "零食乾糧": self.emoji = "🍪"; self.name = rawValue
            case "藥品保健": self.emoji = "💊"; self.name = rawValue
            case "美妝保養": self.emoji = "✨"; self.name = rawValue
            default:
                self.emoji = "📦"
                self.name = rawValue
            }
        }
    }
    
    var label: String { "\(emoji) \(name)" }
    
    static let refrigerated = ItemCategory(emoji: "🥛", name: "冷藏食品")
    static let snacks = ItemCategory(emoji: "🍪", name: "零食乾糧")
    static let medicine = ItemCategory(emoji: "💊", name: "藥品保健")
    static let beauty = ItemCategory(emoji: "✨", name: "美妝保養")
}


enum ExpiryStatus {
    case expired
    case urgent
    case safe
    
    var color: Color {
        switch self {
        case .expired: return .red
        case .urgent: return .orange
        case .safe: return .green
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .expired: return .red.opacity(0.1)
        case .urgent: return .orange.opacity(0.1)
        case .safe: return .green.opacity(0.1)
        }
    }
}

struct DateHelpers {
    static func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return components.day ?? 0
    }
    
    static func expiryStatus(for date: Date) -> ExpiryStatus {
        let days = daysUntil(date)
        if days < 0 { return .expired }
        if days <= 3 { return .urgent }
        return .safe
    }
    
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
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

@Model
final class TrackedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var expiryDate: Date
    var createdAt: Date
    
    // Reminders (must match main app schema)
    var reminder1Days: Int?
    var reminder2Days: Int?
    var reminderTime: Date?
    
    init(id: UUID = UUID(), name: String, categoryRaw: String, expiryDate: Date, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.categoryRaw = categoryRaw
        self.expiryDate = expiryDate
        self.createdAt = createdAt
    }
    
    @Transient var category: ItemCategory {
        ItemCategory(rawValue: categoryRaw) ?? .refrigerated
    }
    
    @Transient var daysRemaining: Int {
        DateHelpers.daysUntil(expiryDate)
    }
    
    @Transient var status: ExpiryStatus {
        DateHelpers.expiryStatus(for: expiryDate)
    }
    
    @Transient var statusLabel: String {
        DateHelpers.statusLabel(for: expiryDate)
    }
}

@Model
final class ArchivedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var expiryDate: Date
    var archivedAt: Date
    var reasonRaw: String
    
    init(name: String, categoryRaw: String, expiryDate: Date, reasonRaw: String) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = categoryRaw
        self.expiryDate = expiryDate
        self.archivedAt = .now
        self.reasonRaw = reasonRaw
    }
}

// MARK: - Sendable Snapshot
struct TrackedItemSnapshot: Sendable, Identifiable {
    let id: UUID
    let name: String
    let expiryDate: Date
    let category: ItemCategory
    
    var daysRemaining: Int {
        DateHelpers.daysUntil(expiryDate)
    }
    
    var status: ExpiryStatus {
        DateHelpers.expiryStatus(for: expiryDate)
    }
    
    var statusLabel: String {
        DateHelpers.statusLabel(for: expiryDate)
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "效期守護" }
    static var description: IntentDescription { IntentDescription("查看即將到期的物品") }
}

// MARK: - Timeline Provider
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ExpiryEntry {
        ExpiryEntry(date: Date(), items: [
            TrackedItemSnapshot(id: UUID(), name: "牛奶", expiryDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!, category: .refrigerated),
            TrackedItemSnapshot(id: UUID(), name: "餅乾", expiryDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!, category: .snacks)
        ])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ExpiryEntry {
        let items = await getItems()
        if items.isEmpty {
            return ExpiryEntry(date: Date(), items: [
                TrackedItemSnapshot(id: UUID(), name: "牛奶", expiryDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!, category: .refrigerated)
            ])
        }
        return ExpiryEntry(date: Date(), items: items)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ExpiryEntry> {
        let entries = [ExpiryEntry(date: Date(), items: await getItems())]
        
        // Refresh next midnight or in an hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        
        return Timeline(entries: entries, policy: .after(nextUpdate))
    }
    
    @MainActor
    private func getItems() -> [TrackedItemSnapshot] {
        do {
            let schema = Schema([TrackedItem.self, ArchivedItem.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(SharedConstants.appGroupID)
            )
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let descriptor = FetchDescriptor<TrackedItem>(sortBy: [SortDescriptor(\.expiryDate)])
            let fetchedItems = try container.mainContext.fetch(descriptor)
            
            return fetchedItems.map { item in
                TrackedItemSnapshot(
                    id: item.id,
                    name: item.name,
                    expiryDate: item.expiryDate,
                    category: item.category
                )
            }
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
}

struct ExpiryEntry: TimelineEntry {
    let date: Date
    let items: [TrackedItemSnapshot]
}

// MARK: - Widget View
struct ExpiryWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }
    
    var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("效期雷達")
                .font(.headline)
                .bold()
            
            if let firstItem = entry.items.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(firstItem.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Text(firstItem.statusLabel)
                        .font(.caption)
                        .bold()
                        .foregroundColor(firstItem.status.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(firstItem.status.backgroundColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                if entry.items.count > 1 {
                    Text("+ \(entry.items.count - 1) 件其他物品")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Spacer()
                Text("全部安全 ✅")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("效期守護")
                    .font(.headline)
                    .bold()
                Spacer()
                
                let urgentCount = entry.items.filter { $0.status == .expired || $0.status == .urgent }.count
                if urgentCount > 0 {
                    Text("\(urgentCount) 件緊急")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            if entry.items.isEmpty {
                Spacer()
                Text("所有物品都安全儲存中 ✅")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(spacing: 4) {
                    ForEach(entry.items.prefix(3), id: \.id) { item in
                        HStack {
                            Text("\(item.category.emoji) \(item.name)")
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(DateHelpers.formatDate(item.expiryDate))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(item.statusLabel)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(item.status.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.status.backgroundColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Definition
struct ExpiryWidget: Widget {
    let kind: String = "ExpiryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            ExpiryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("效期守護")
        .description("查看即將到期的物品")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
