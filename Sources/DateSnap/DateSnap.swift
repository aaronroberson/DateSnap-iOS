import SwiftUI
import SwiftData

@main
struct DateSnapApp: App {
    @StateObject private var services = ServiceContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView(services: services)
                .dateSnapServices(services)
        }
        .modelContainer(for: [
            UserSettings.self,
            ScannedAsset.self,
            EventCandidate.self,
            SavedEvent.self,
            InterpretationRecord.self
        ])
    }
}