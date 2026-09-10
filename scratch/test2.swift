import Foundation
import SwiftData

@Model
final class TrackedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var expiryDate: Date
    var createdAt: Date
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
        // Step 1: Create store with ONLY TrackedItem
        let url = URL(fileURLWithPath: "/tmp/test_migration.store")
        try? FileManager.default.removeItem(at: url)
        let schema1 = Schema([TrackedItem.self])
        let config1 = ModelConfiguration(schema: schema1, url: url)
        let container1 = try ModelContainer(for: schema1, configurations: [config1])
        container1.mainContext.insert(TrackedItem(name: "Apples", categoryRaw: "fruits", expiryDate: Date()))
        try container1.mainContext.save()
        print("Store 1 created with only TrackedItem")
        
        // Step 2: Now open with Schema([TrackedItem.self, ArchivedItem.self])
        let schema2 = Schema([TrackedItem.self, ArchivedItem.self])
        let config2 = ModelConfiguration(schema: schema2, url: url)
        do {
            let container2 = try ModelContainer(for: schema2, configurations: [config2])
            let archived = ArchivedItem(name: "Old Apple", categoryRaw: "fruits", expiryDate: Date(), reasonRaw: "consumed")
            container2.mainContext.insert(archived)
            try container2.mainContext.save()
            
            let fetch = FetchDescriptor<ArchivedItem>()
            let results = try container2.mainContext.fetch(fetch)
            print("Step 2 results count: \(results.count)")
        } catch {
            print("Step 2 failed with error: \(error)")
        }
    }
}
