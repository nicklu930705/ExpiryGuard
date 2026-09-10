import Foundation
import SwiftData

enum SharedConstants {
    /// App Group identifier — 主 App 與 Widget 共享資料用
    static let appGroupID = "group.com.lutsehsien.expiryguard.shared"
    
    @MainActor
    public static let sharedModelContainer: ModelContainer = {
        let schema = Schema([TrackedItem.self, ArchivedItem.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupID)
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
