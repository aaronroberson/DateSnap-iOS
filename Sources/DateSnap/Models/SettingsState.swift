import SwiftUI

// State for the Settings cluster (Settings Hub, Privacy Center, Automation,
// Reminder Defaults, Manage Plan). Kept separate from the core AppState so
// both can evolve independently; toasts still route through AppState.
@MainActor
final class SettingsState: ObservableObject {
    // MARK: - Plan / Billing (Settings Hub <-> Manage Plan)
    @Published var isAnnual: Bool = true
    @Published var autoRenewal: Bool = true

    var planName: String { isAnnual ? "DateSnap Plus (Annual)" : "DateSnap Plus (Monthly)" }
    var planPrice: String { isAnnual ? "$29.99" : "$4.99" }

    // MARK: - Privacy & Security (Settings Hub <-> Privacy Center)
    @Published var screenshotAutoPurge: Bool = true
    @Published var faceIDProtection: Bool = true

    enum PurgeWindow: String, CaseIterable, Identifiable {
        case immediate = "Immediate"
        case sevenDays = "After 7 days"
        case thirtyDays = "After 30 days"
        case manual = "Manual only"
        var id: String { rawValue }
    }
    @Published var purgeWindow: PurgeWindow = .immediate

    // MARK: - Scanning & Capture (Settings Hub <-> Automation Settings)
    enum ScanProfile: String, CaseIterable, Identifiable {
        case review = "Review Mode"
        case smartSave = "Smart Save Mode"
        case manual = "Manual Only"
        var id: String { rawValue }

        var badge: String {
            switch self {
            case .review: return "Recommended"
            case .smartSave: return "Experimental"
            case .manual: return "Zero Activity"
            }
        }
        var subtitle: String {
            switch self {
            case .review: return "Safe AI Automation"
            case .smartSave: return "High Velocity"
            case .manual: return "Zero Background Activity"
            }
        }
        var blurb: String {
            switch self {
            case .review:
                return "Scans detected screenshots instantly on app wake. Confirms temporal badges with you before saving to calendar."
            case .smartSave:
                return "Auto-commits ultra-clear events (>95% confidence) to your primary calendar; holds ambiguous flyers in review tray."
            case .manual:
                return "Background listeners remain dormant. Scans trigger exclusively when you tap Scan or invoke the iOS Share Sheet."
            }
        }
        var icon: String {
            switch self {
            case .review: return "rule.fill"
            case .smartSave: return "auto.fix.high"
            case .manual: return "hand.tap.fill"
            }
        }
    }
    @Published var scanProfile: ScanProfile = .review
    @Published var captureScopeCameraPhotos: Bool = false
    @Published var includeAirDropShared: Bool = true
    @Published var confidence: Double = 85
    @Published var draftLowConfidence: Bool = true

    // MARK: - Digest & Notifications
    @Published var quickExtractionPrompt: Bool = true
    @Published var eveningDigest: Bool = true
    @Published var pauseOnLowPower: Bool = true

    // MARK: - Reminder Defaults (Settings Hub <-> Default Reminder Settings)
    struct TimedAlert: Identifiable {
        let id = UUID()
        var glyph: String
        var title: String
        var time: Date
        var channel: String
    }

    enum TimedPreset: String, CaseIterable, Identifiable {
        case thorough = "Thorough"
        case standard = "Standard"
        case minimal = "Minimal"
        var id: String { rawValue }

        var alertCount: Int {
            switch self {
            case .thorough: return 3
            case .standard: return 2
            case .minimal: return 1
            }
        }
        var caption: String { "\(alertCount) alerts" }
    }

    enum DeliveryRoute: String, CaseIterable, Identifiable {
        case calendar = "Calendar"
        case reminders = "Reminders"
        case push = "DateSnap"
        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .calendar: return "Primary"
            case .reminders: return "Actionable"
            case .push: return "Push Ping"
            }
        }
        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .reminders: return "checklist"
            case .push: return "notifications"
            }
        }
    }

    @Published var timedPreset: TimedPreset = .thorough
    @Published var timedAlerts: [TimedAlert] = [
        TimedAlert(glyph: "bell.badge.fill", title: "1 Day Before",
                   time: Calendar.current.date(from: DateComponents(hour: 9)) ?? Date(),
                   channel: "Apple Reminders"),
        TimedAlert(glyph: "hourglass", title: "2 Hours Before",
                   time: Calendar.current.date(from: DateComponents(hour: 18, minute: 30)) ?? Date(),
                   channel: "Calendar Notification"),
        TimedAlert(glyph: "bolt.fill", title: "30 Minutes Before",
                   time: Calendar.current.date(from: DateComponents(hour: 19, minute: 30)) ?? Date(),
                   channel: "DateSnap Local Push"),
    ]
    @Published var allDayDayOf: Bool = true
    @Published var allDayDayBefore: Bool = true
    @Published var routePrimary: DeliveryRoute = .calendar
    @Published var alertSound: String = "Crystal Chime (Haptic Pulse)"

    // Deep-link route from the Screen Gallery into this cluster.
    @Published var pendingRoute: String? = nil

    func applyTimedPreset(_ preset: TimedPreset) {
        timedPreset = preset
        timedAlerts = Array(timedAlerts.prefix(preset.alertCount))
    }

    func resetReminderDefaults() {
        timedPreset = .standard
        timedAlerts = [
            TimedAlert(glyph: "bell.badge.fill", title: "1 Day Before",
                       time: Calendar.current.date(from: DateComponents(hour: 9)) ?? Date(),
                       channel: "Apple Reminders"),
            TimedAlert(glyph: "hourglass", title: "2 Hours Before",
                       time: Calendar.current.date(from: DateComponents(hour: 18, minute: 30)) ?? Date(),
                       channel: "Calendar Notification"),
        ]
        allDayDayOf = true
        allDayDayBefore = true
        routePrimary = .calendar
        alertSound = "Crystal Chime (Haptic Pulse)"
    }
}
