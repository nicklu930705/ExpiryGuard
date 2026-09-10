import SwiftUI
import SwiftData

@main
struct ExpiryGuardApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedConstants.sharedModelContainer)
    }
}
