import Foundation
import SwiftData

@Model
final class TrackedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var expiryDate: Date
    var createdAt: Date
    var reminder1Days: Int?
    var reminder2Days: Int?
    var reminderTime: Date?
    init(name: String, categoryRaw: String, expiryDate: Date) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = categoryRaw
        self.expiryDate = expiryDate
        self.createdAt = .now
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

@main
struct Script {
    @MainActor static func main() throws {
        let schema = Schema([TrackedItem.self, ArchivedItem.self])
        let url = URL(fileURLWithPath: "/tmp/test_swiftdata.store")
        try? FileManager.default.removeItem(at: url)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let item = TrackedItem(name: "Milk", categoryRaw: "dairy", expiryDate: Date())
        context.insert(item)
        let archived = ArchivedItem(name: "Old Milk", categoryRaw: "dairy", expiryDate: Date(), reasonRaw: "wasted")
        context.insert(archived)
        try context.save()
        print("SUCCESS! Created store at /tmp/test_swiftdata.store")
    }
}
