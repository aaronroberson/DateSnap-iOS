import Foundation

// MARK: - Reminder Defaults Store
/// Persists the reminder preset every new event starts with (Settings → Default Reminders).
/// Unset means Standard, the alerts Pencil’d has always used, so existing installs keep their behavior.
/// Saved events keep their own alerts; the free plan still keeps only the first alert.
struct ReminderDefaultsStore: Sendable {
    static let defaultsKey = "settings.defaultReminderPreset"
    private let defaultsSuiteName: String?

    init(defaultsSuiteName: String? = nil) {
        self.defaultsSuiteName = defaultsSuiteName
    }

    private var defaults: UserDefaults {
        defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The chosen preset, or Standard when none (or an unknown value) is stored.
    func preset() -> ReminderPreset {
        guard let raw = defaults.string(forKey: Self.defaultsKey),
              let preset = ReminderPreset(rawValue: raw),
              ReminderPreset.defaultChoices.contains(preset) else { return .defaultPreset }
        return preset
    }

    func setPreset(_ preset: ReminderPreset) {
        guard ReminderPreset.defaultChoices.contains(preset) else { return }
        defaults.set(preset.rawValue, forKey: Self.defaultsKey)
    }

    /// The alerts a new event starts with.
    func defaultOffsets() -> [ReminderOffset] {
        preset().offsets ?? ReminderOffset.defaultStaggered
    }
}
