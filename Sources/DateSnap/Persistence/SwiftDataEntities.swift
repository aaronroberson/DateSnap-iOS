import Foundation
import SwiftData

// MARK: - Confidence Tier Enum

public enum ConfidenceTier: String, CaseIterable, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public var label: String {
        switch self {
        case .high: return "High AI Accuracy"
        case .medium: return "Review Suggested"
        case .low: return "Low Confidence"
        }
    }

    public var iconName: String {
        switch self {
        case .high: return "sparkles"
        case .medium: return "eye.fill"
        case .low: return "exclamationmark.triangle.fill"
        }
    }

    /// Color tokens from DateSnap Design System (Success #46E39A, Warning #FFBE55, Error #FF6B7A)
    public var hexColor: String {
        switch self {
        case .high: return "46E39A"
        case .medium: return "FFBE55"
        case .low: return "FF6B7A"
        }
    }

    public static func from(score: Float) -> ConfidenceTier {
        if score >= 0.90 {
            return .high
        } else if score >= 0.70 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - User Settings Model
@Model
public final class UserSettings {
    @Attribute(.unique) public var id: String
    public var defaultCalendarId: String?
    public var defaultReminderListId: String?
    public var autoScanEnabled: Bool
    public var alertPresetRaw: String
    public var defaultStaggeredOffsets: [Double] // Negative seconds before event
    public var isPlusActive: Bool
    public var isPremiumActive: Bool
    public var hasCompletedOnboarding: Bool
    public var lastScanDate: Date?
    public var createdAt: Date

    public init(
        id: String = "user_settings_singleton",
        defaultCalendarId: String? = nil,
        defaultReminderListId: String? = nil,
        autoScanEnabled: Bool = true,
        alertPresetRaw: String = "Default (2 alerts)",
        defaultStaggeredOffsets: [Double] = [-86400, -7200], // 1 day, 2 hours
        isPlusActive: Bool = false,
        isPremiumActive: Bool = false,
        hasCompletedOnboarding: Bool = false,
        lastScanDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.defaultCalendarId = defaultCalendarId
        self.defaultReminderListId = defaultReminderListId
        self.autoScanEnabled = autoScanEnabled
        self.alertPresetRaw = alertPresetRaw
        self.defaultStaggeredOffsets = defaultStaggeredOffsets
        self.isPlusActive = isPlusActive
        self.isPremiumActive = isPremiumActive
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastScanDate = lastScanDate
        self.createdAt = createdAt
    }
}

// MARK: - Scanned Photo / Screenshot Asset
@Model
public final class ScannedAsset {
    @Attribute(.unique) public var id: String
    public var assetIdentifier: String
    public var scannedAt: Date
    public var rawOcrText: String
    public var ocrConfidence: Float
    public var isProcessed: Bool
    public var candidateCount: Int

    @Relationship(deleteRule: .cascade, inverse: \EventCandidate.scannedAsset)
    public var candidates: [EventCandidate] = []

    public init(
        id: String = UUID().uuidString,
        assetIdentifier: String,
        scannedAt: Date = Date(),
        rawOcrText: String = "",
        ocrConfidence: Float = 0.0,
        isProcessed: Bool = false,
        candidateCount: Int = 0
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.scannedAt = scannedAt
        self.rawOcrText = rawOcrText
        self.ocrConfidence = ocrConfidence
        self.isProcessed = isProcessed
        self.candidateCount = candidateCount
        self.candidates = []
    }
}

// MARK: - Event Candidate (Extracted from OCR)
@Model
public final class EventCandidate {
    @Attribute(.unique) public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date?
    public var isAllDay: Bool
    public var location: String?
    public var venueName: String?
    public var rsvpUrl: String?
    public var confidenceScore: Float // 0.0 ... 1.0
    public var yearAssumed: Bool
    public var rawTextSnippet: String
    public var createdAt: Date

    // Additive metadata fields
    public var dateConfidence: Float = 0.85
    public var titleConfidence: Float = 0.85
    public var confidenceTierRaw: String = "High"
    public var isAmbiguousDate: Bool = false
    public var ambiguousFragment: String? = nil
    public var timeZoneIdentifier: String? = nil
    public var dedupeKey: String = ""
    public var phoneNumber: String? = nil
    public var email: String? = nil
    public var notes: String = ""
    /// Content-based identity (normalized title, day, venue) for matching the same event across screenshots.
    public var similarityKey: String = ""
    /// `EventCategory` raw value suggested by understanding (editable in review).
    public var categoryRaw: String = "other"
    /// RSVP / registration deadline found on the flyer, if any.
    public var rsvpDeadline: Date? = nil
    /// `RecurrenceSignal.Kind` raw value, set only when the user chooses to repeat the event in Calendar.
    public var recurrenceRaw: String? = nil

    /// Alternatives, evidence and provenance from the scan that produced this candidate.
    @Relationship(deleteRule: .cascade, inverse: \InterpretationRecord.candidate)
    public var interpretation: InterpretationRecord?

    public var scannedAsset: ScannedAsset?

    @Relationship(deleteRule: .cascade, inverse: \SavedEvent.candidate)
    public var savedEvent: SavedEvent?

    public var confidenceTier: ConfidenceTier {
        ConfidenceTier(rawValue: confidenceTierRaw) ?? ConfidenceTier.from(score: confidenceScore)
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        venueName: String? = nil,
        rsvpUrl: String? = nil,
        confidenceScore: Float = 0.85,
        yearAssumed: Bool = false,
        rawTextSnippet: String = "",
        createdAt: Date = Date(),
        dateConfidence: Float = 0.85,
        titleConfidence: Float = 0.85,
        confidenceTierRaw: String = "High",
        isAmbiguousDate: Bool = false,
        ambiguousFragment: String? = nil,
        timeZoneIdentifier: String? = nil,
        dedupeKey: String = "",
        phoneNumber: String? = nil,
        email: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.venueName = venueName
        self.rsvpUrl = rsvpUrl
        self.confidenceScore = confidenceScore
        self.yearAssumed = yearAssumed
        self.rawTextSnippet = rawTextSnippet
        self.createdAt = createdAt
        self.dateConfidence = dateConfidence
        self.titleConfidence = titleConfidence
        self.confidenceTierRaw = confidenceTierRaw
        self.isAmbiguousDate = isAmbiguousDate
        self.ambiguousFragment = ambiguousFragment
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dedupeKey = dedupeKey
        self.phoneNumber = phoneNumber
        self.email = email
        self.notes = notes
    }
}

// MARK: - Interpretation Record
/// Versioned review bundle for one candidate: the best interpretation, alternatives, evidence lines and
/// field provenance, plus which alternative the user chose and which fields they corrected. OCR evidence stays
/// on device like the rest of the scan. Deleted with its candidate.
@Model
public final class InterpretationRecord {
    public var schemaVersion: Int
    public var engineRoute: String
    public var fallbackReason: String?
    /// JSON-encoded `StoredInterpretation`.
    public var payload: Data
    public var selectedInterpretationID: String?
    public var correctedFields: [String]
    public var createdAt: Date

    public var candidate: EventCandidate?

    public init(
        schemaVersion: Int = EventUnderstandingResult.schemaVersion,
        engineRoute: String,
        fallbackReason: String? = nil,
        payload: Data,
        selectedInterpretationID: String? = nil,
        correctedFields: [String] = [],
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.engineRoute = engineRoute
        self.fallbackReason = fallbackReason
        self.payload = payload
        self.selectedInterpretationID = selectedInterpretationID
        self.correctedFields = correctedFields
        self.createdAt = createdAt
    }
}

/// Codable payload of an `InterpretationRecord`.
public struct StoredInterpretation: Codable, Sendable {
    public var understanding: EventUnderstanding
    public var evidence: [EvidenceLine]
    public var route: EngineRoute
    public var quality: OCRQualityReport

    public init(understanding: EventUnderstanding, evidence: [EvidenceLine], route: EngineRoute, quality: OCRQualityReport) {
        self.understanding = understanding
        self.evidence = evidence
        self.route = route
        self.quality = quality
    }
}

extension InterpretationRecord {
    /// Builds a record for a freshly scanned candidate. Returns nil if encoding fails.
    static func make(for understanding: EventUnderstanding, in result: EventUnderstandingResult) -> InterpretationRecord? {
        let stored = StoredInterpretation(understanding: understanding, evidence: result.evidence, route: result.route, quality: result.quality)
        guard let data = try? JSONEncoder().encode(stored) else { return nil }
        return InterpretationRecord(engineRoute: result.route.rawValue, fallbackReason: result.fallbackReason, payload: data,
                                    selectedInterpretationID: understanding.best.id)
    }

    /// Decodes the payload; nil for unknown future schema versions or corrupt data.
    var stored: StoredInterpretation? {
        guard schemaVersion <= EventUnderstandingResult.schemaVersion else { return nil }
        return try? JSONDecoder().decode(StoredInterpretation.self, from: payload)
    }
}

// MARK: - Saved Event Status

/// Persisted lifecycle of a `SavedEvent`; raw values are stored in `SavedEvent.statusRaw`.
public enum SavedEventStatus: String, CaseIterable, Sendable {
    case saved = "Saved"
    case draft = "Draft"
    case archived = "Archived"

    var eventStatus: EventStatus {
        switch self {
        case .saved: return .saved
        case .draft: return .draft
        case .archived: return .dismissed
        }
    }
}

// MARK: - Saved Event (Committed to Apple Calendar / Reminders)
@Model
public final class SavedEvent {
    @Attribute(.unique) public var id: String
    public var externalCalendarEventId: String?
    public var externalReminderIds: [String]
    public var scheduledNotificationIds: [String]
    public var createdAt: Date
    public var targetCalendar: String
    public var targetRemindersList: String
    public var statusRaw: String
    /// Alert offsets (negative seconds before start) currently applied to the calendar, reminder and local alerts.
    public var alertOffsets: [Double] = []
    /// Separate RSVP/registration-deadline reminder the user accepted, if any.
    public var deadlineReminderId: String? = nil

    public var candidate: EventCandidate?

    public var status: SavedEventStatus {
        get { SavedEventStatus(rawValue: statusRaw) ?? .saved }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        externalCalendarEventId: String? = nil,
        externalReminderIds: [String] = [],
        scheduledNotificationIds: [String] = [],
        createdAt: Date = Date(),
        targetCalendar: String = "Default",
        targetRemindersList: String = "Reminders",
        statusRaw: String = "Saved",
        alertOffsets: [Double] = [],
        candidate: EventCandidate? = nil
    ) {
        self.id = id
        self.externalCalendarEventId = externalCalendarEventId
        self.externalReminderIds = externalReminderIds
        self.scheduledNotificationIds = scheduledNotificationIds
        self.createdAt = createdAt
        self.targetCalendar = targetCalendar
        self.targetRemindersList = targetRemindersList
        self.statusRaw = statusRaw
        self.alertOffsets = alertOffsets
        self.candidate = candidate
    }
}

// MARK: - Convenience Conversions with DateSnapEvent UI Struct
extension EventCandidate {
    func toDateSnapEvent() -> DateSnapEvent {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let timeWindow: String
        if isAllDay {
            timeWindow = "All Day"
        } else if let end = endDate {
            timeWindow = "\(timeFormatter.string(from: startDate)) – \(timeFormatter.string(from: end))"
        } else {
            timeWindow = timeFormatter.string(from: startDate)
        }

        let tier = confidenceTier
        let saved = savedEvent
        let offsets = saved?.alertOffsets.map { ReminderOffset.forInterval($0) } ?? []

        var noteLines: [String] = []
        if !notes.isEmpty { noteLines.append(notes) }
        if let rsvpUrl { noteLines.append("RSVP: \(rsvpUrl)") }

        return DateSnapEvent(
            id: id,
            title: title,
            month: monthFormatter.string(from: startDate),
            day: dayFormatter.string(from: startDate),
            year: yearFormatter.string(from: startDate),
            dayOfWeek: weekdayFormatter.string(from: startDate),
            timeWindow: timeWindow,
            locationName: venueName ?? (location ?? "Location TBA"),
            locationAddress: location ?? "",
            confidenceScore: Int(confidenceScore * 100),
            confidenceLabel: tier.label,
            status: saved?.status.eventStatus ?? .draft,
            sourceFlyerName: scannedAsset != nil ? "Scanned Image" : "Manual Entry",
            sourceFlyerMetadata: scannedAsset.map { "Scanned on-device \($0.scannedAt.formatted(date: .abbreviated, time: .shortened))" } ?? "Entered manually",
            targetCalendar: saved?.targetCalendar ?? "Default Calendar",
            targetRemindersList: saved?.targetRemindersList ?? "Reminders",
            rawOcrFragments: rawTextSnippet.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            scheduledAlerts: offsets.map { ReminderAlert(offset: $0, eventStart: startDate, isAllDay: isAllDay) },
            isAllDay: isAllDay,
            notes: noteLines.joined(separator: "\n"),
            isAmbiguousDate: isAmbiguousDate,
            ambiguousFragment: ambiguousFragment,
            timeZoneIdentifier: timeZoneIdentifier,
            dedupeKey: dedupeKey
        )
    }
}
