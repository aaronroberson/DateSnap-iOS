import SwiftUI

@MainActor
final class SettingsState: ObservableObject {
    /// Deep-link route from the Settings Hub and help screens.
    @Published var pendingRoute: String?
}
