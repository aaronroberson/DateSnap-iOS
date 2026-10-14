import EventKit
import Photos
import UserNotifications

// MARK: - Permission Access
/// One reading of each system permission, so Settings, Home and the services agree on what a
/// status means. `partial` is access the app can work with but not fully: limited Photos (only the
/// photos the user picked) and add-only Calendar (events can be saved, calendars can't be listed).
enum PermissionAccess: Equatable {
    case granted
    case partial
    case denied
    case notAsked

    /// The app can use the permission for its core job (reading chosen photos, saving events,
    /// delivering alerts).
    var isUsable: Bool { self == .granted || self == .partial }
}

extension PHAuthorizationStatus {
    var access: PermissionAccess {
        switch self {
        case .authorized: return .granted
        case .limited: return .partial
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    var settingsLabel: String {
        switch access {
        case .granted: return "Full Access"
        case .partial: return "Limited"
        case .notAsked: return "Not Asked"
        case .denied: return "Off"
        }
    }
}

extension EKAuthorizationStatus {
    var access: PermissionAccess {
        switch self {
        case .fullAccess: return .granted
        case .writeOnly: return .partial
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    /// Listing calendars (the default-calendar picker, duplicate checks) needs full access.
    var canReadCalendars: Bool { access == .granted }

    var settingsLabel: String {
        switch access {
        case .granted: return "Full Access"
        case .partial: return "Add Only"
        case .notAsked: return "Not Asked"
        case .denied: return "Off"
        }
    }
}

extension UNAuthorizationStatus {
    var access: PermissionAccess {
        switch self {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    var settingsLabel: String {
        switch access {
        case .granted, .partial: return "On"
        case .notAsked: return "Not Asked"
        case .denied: return "Off"
        }
    }
}
