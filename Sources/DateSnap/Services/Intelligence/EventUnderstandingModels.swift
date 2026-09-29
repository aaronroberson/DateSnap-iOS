import Foundation
import CoreGraphics

// MARK: - Event Understanding Value Contracts
//
// Value types exchanged between OCR, deterministic extraction, the optional on-device interpreter,
// the validator and the review UI. They are `Sendable` so they can cross actor boundaries (no SwiftData
// models ever enter the interpreter) and `Codable` so a review can be persisted as an `InterpretationRecord`.

/// Where a field value came from. Drives the "Confirmed from flyer" / "Inferred" / "Please check" labels.
public enum FieldProvenance: String, Sendable, Codable, CaseIterable {
    /// Copied verbatim from a recognized OCR line (e.g. a URL, a labeled time).
    case explicitText
    /// Produced by the deterministic parser's rules (e.g. title by typography, assumed year).
    case deterministicRule
    /// Chosen or re-labeled by the on-device model and accepted by the validator.
    case modelInterpretation
    /// A labeled default with no flyer evidence (e.g. a 2-hour duration).
    case fallbackDefault
    /// Changed by the user in review; always the source of truth once set.
    case userEdited
}

/// A pointer to one recognized OCR line. Evidence text stays on device and is only shown locally.
public struct EvidenceReference: Sendable, Codable, Hashable {
    public var lineID: Int
    public var confidence: Float

    public init(lineID: Int, confidence: Float) {
        self.lineID = lineID
        self.confidence = confidence
    }
}

/// One recognized OCR line with a stable identifier and layout features.
public struct EvidenceLine: Sendable, Codable, Hashable, Identifiable {
    public var id: Int
    public var blockID: Int
    public var text: String
    public var confidence: Float
    /// Vision-normalized bounding box (origin lower-left).
    public var boundingBox: CGRect
    /// 0 = largest type on the page.
    public var fontRank: Int

    public init(id: Int, blockID: Int, text: String, confidence: Float, boundingBox: CGRect, fontRank: Int) {
        self.id = id
        self.blockID = blockID
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.fontRank = fontRank
    }
}

/// A proposed value for one event field plus how trustworthy it is.
public struct FieldAssessment<Value: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    public var value: Value
    public var provenance: FieldProvenance
    public var evidence: [EvidenceReference]
    /// Evidence strength in 0...1 derived from OCR confidence and rule agreement — never model self-reports.
    public var score: Float
    public var isAmbiguous: Bool
    /// Short, evidence-grounded reason shown in "Why this?".
    public var reason: String?

    public init(
        value: Value,
        provenance: FieldProvenance,
        evidence: [EvidenceReference] = [],
        score: Float,
        isAmbiguous: Bool = false,
        reason: String? = nil
    ) {
        self.value = value
        self.provenance = provenance
        self.evidence = evidence
        self.score = score
        self.isAmbiguous = isAmbiguous
        self.reason = reason
    }
}

/// What a date or time on the flyer refers to.
public enum TemporalRole: String, Sendable, Codable, CaseIterable {
    case eventDate, doors, show, eventEnd, rsvpDeadline, ticketSale, other
}

/// One temporal fragment found in the OCR text, classified by role.
public struct TemporalEvidence: Sendable, Codable, Hashable {
    public var fragment: String
    public var role: TemporalRole
    public var lineID: Int
    public var hour: Int?
    public var minute: Int?
    /// Calendar day when the fragment contains one (normalized to the event's calendar).
    public var date: Date?

    public init(fragment: String, role: TemporalRole, lineID: Int, hour: Int? = nil, minute: Int? = nil, date: Date? = nil) {
        self.fragment = fragment
        self.role = role
        self.lineID = lineID
        self.hour = hour
        self.minute = minute
        self.date = date
    }
}

/// Broad event category, used for duration priors, calendar suggestions and reminder plans.
public enum EventCategory: String, Sendable, Codable, CaseIterable {
    case concert, nightlife, conference, appointment, sports, festival, classOrWorkshop, social, deadline, other

    public var displayName: String {
        switch self {
        case .concert: return "Concert / Show"
        case .nightlife: return "Nightlife"
        case .conference: return "Conference / Talk"
        case .appointment: return "Appointment"
        case .sports: return "Sports"
        case .festival: return "Festival"
        case .classOrWorkshop: return "Class / Workshop"
        case .social: return "Social"
        case .deadline: return "Deadline"
        case .other: return "Event"
        }
    }
}

public enum DurationSource: String, Sendable, Codable {
    /// The flyer states an end time or range.
    case explicit
    /// No end on the flyer; duration suggested from the category.
    case categoryDefault
    /// No end and no category signal; the labeled two-hour fallback.
    case fallback
}

public enum TimeZoneSource: String, Sendable, Codable {
    /// A zone abbreviation or name is printed on the flyer.
    case explicit
    /// The device's current zone.
    case deviceLocal
}

/// A user-confirmable action found on the flyer (never performed automatically).
public struct ActionSuggestion: Sendable, Codable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case rsvp, buyTickets, register, call, email, website
    }

    public var id: String { "\(kind.rawValue)|\(target)" }
    public var kind: Kind
    /// Exact URL, phone number or email copied from the OCR text.
    public var target: String
    public var deadline: Date?
    public var evidence: [EvidenceReference]

    public init(kind: Kind, target: String, deadline: Date? = nil, evidence: [EvidenceReference] = []) {
        self.kind = kind
        self.target = target
        self.deadline = deadline
        self.evidence = evidence
    }

    public var title: String {
        switch kind {
        case .rsvp: return "RSVP"
        case .buyTickets: return "Buy tickets"
        case .register: return "Register"
        case .call: return "Call"
        case .email: return "Email"
        case .website: return "Open website"
        }
    }
}

/// A hint that the event repeats. Offered as a suggestion only; recurrence is never written without a choice.
public struct RecurrenceSignal: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable {
        case weekly, monthly, series
    }

    public var kind: Kind
    public var phrase: String
    public var lineID: Int

    public init(kind: Kind, phrase: String, lineID: Int) {
        self.kind = kind
        self.phrase = phrase
        self.lineID = lineID
    }
}

/// A full, editable hypothesis for one event.
public struct EventInterpretationCandidate: Sendable, Codable, Identifiable, Equatable {
    public var id: String
    public var title: FieldAssessment<String>
    public var start: FieldAssessment<Date>
    public var end: FieldAssessment<Date?>
    public var isAllDay: Bool
    public var venue: FieldAssessment<String?>
    public var address: FieldAssessment<String?>
    public var organizer: FieldAssessment<String?>
    public var performer: FieldAssessment<String?>
    public var doorsTime: Date?
    public var category: EventCategory
    public var durationSource: DurationSource
    public var timeZoneIdentifier: String?
    public var timeZoneSource: TimeZoneSource
    public var notesSummary: String
    public var yearAssumed: Bool
    public var isAmbiguousDate: Bool
    public var ambiguousFragment: String?
    public var rsvpUrl: String?
    public var phoneNumber: String?
    public var email: String?
    public var rawSnippet: String
    /// Asset-bound identity for resume-after-rescan.
    public var dedupeKey: String
    /// Content-based identity for matching the same event across different screenshots.
    public var similarityKey: String
    /// Overall ranking score in 0...1 (evidence strength, OCR quality, agreement, margin).
    public var rankScore: Float
    /// Which lines each field relied on, plus reason codes, for "Why this?".
    public var explanations: [String]

    public init(
        id: String = UUID().uuidString,
        title: FieldAssessment<String>,
        start: FieldAssessment<Date>,
        end: FieldAssessment<Date?>,
        isAllDay: Bool,
        venue: FieldAssessment<String?>,
        address: FieldAssessment<String?>,
        organizer: FieldAssessment<String?> = FieldAssessment(value: nil, provenance: .deterministicRule, score: 0),
        performer: FieldAssessment<String?> = FieldAssessment(value: nil, provenance: .deterministicRule, score: 0),
        doorsTime: Date? = nil,
        category: EventCategory = .other,
        durationSource: DurationSource = .fallback,
        timeZoneIdentifier: String? = nil,
        timeZoneSource: TimeZoneSource = .deviceLocal,
        notesSummary: String = "",
        yearAssumed: Bool = false,
        isAmbiguousDate: Bool = false,
        ambiguousFragment: String? = nil,
        rsvpUrl: String? = nil,
        phoneNumber: String? = nil,
        email: String? = nil,
        rawSnippet: String = "",
        dedupeKey: String = "",
        similarityKey: String = "",
        rankScore: Float = 0,
        explanations: [String] = []
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.venue = venue
        self.address = address
        self.organizer = organizer
        self.performer = performer
        self.doorsTime = doorsTime
        self.category = category
        self.durationSource = durationSource
        self.timeZoneIdentifier = timeZoneIdentifier
        self.timeZoneSource = timeZoneSource
        self.notesSummary = notesSummary
        self.yearAssumed = yearAssumed
        self.isAmbiguousDate = isAmbiguousDate
        self.ambiguousFragment = ambiguousFragment
        self.rsvpUrl = rsvpUrl
        self.phoneNumber = phoneNumber
        self.email = email
        self.rawSnippet = rawSnippet
        self.dedupeKey = dedupeKey
        self.similarityKey = similarityKey
        self.rankScore = rankScore
        self.explanations = explanations
    }
}

/// A one-tap question shown only when the top interpretations differ in a field that changes the saved event.
public struct AmbiguityQuestion: Sendable, Codable, Hashable, Identifiable {
    public enum Field: String, Sendable, Codable {
        case date, startTime, title, venue
    }

    public struct Option: Sendable, Codable, Hashable, Identifiable {
        public var id: String { candidateID }
        public var label: String
        /// The interpretation this answer selects.
        public var candidateID: String

        public init(label: String, candidateID: String) {
            self.label = label
            self.candidateID = candidateID
        }
    }

    public var id: String { field.rawValue }
    public var field: Field
    public var prompt: String
    public var options: [Option]

    public init(field: Field, prompt: String, options: [Option]) {
        self.field = field
        self.prompt = prompt
        self.options = options
    }
}

/// The best interpretation of one detected event plus materially different alternatives.
public struct EventUnderstanding: Sendable, Codable, Identifiable {
    public var id: String { best.id }
    public var best: EventInterpretationCandidate
    public var alternatives: [EventInterpretationCandidate]
    public var questions: [AmbiguityQuestion]
    public var actions: [ActionSuggestion]
    public var recurrence: RecurrenceSignal?
    public var temporalEvidence: [TemporalEvidence]

    public init(
        best: EventInterpretationCandidate,
        alternatives: [EventInterpretationCandidate] = [],
        questions: [AmbiguityQuestion] = [],
        actions: [ActionSuggestion] = [],
        recurrence: RecurrenceSignal? = nil,
        temporalEvidence: [TemporalEvidence] = []
    ) {
        self.best = best
        self.alternatives = alternatives
        self.questions = questions
        self.actions = actions
        self.recurrence = recurrence
        self.temporalEvidence = temporalEvidence
    }

    /// Best first, then alternatives.
    public var allCandidates: [EventInterpretationCandidate] { [best] + alternatives }
}

/// Deterministic scan-quality metrics computed from OCR, before any semantic pass.
public struct OCRQualityReport: Sendable, Codable, Equatable {
    public var lineCount: Int
    public var characterCount: Int
    public var meanConfidence: Float
    /// Share of lines below 0.5 recognition confidence.
    public var lowConfidenceFraction: Float
    /// Share of the image area covered by recognized text.
    public var textCoverage: Float
    /// Whether the text looks like it could describe an event (date/time cues present, not a receipt).
    public var isScanWorthy: Bool
    public var reasons: [String]

    public init(
        lineCount: Int,
        characterCount: Int,
        meanConfidence: Float,
        lowConfidenceFraction: Float,
        textCoverage: Float,
        isScanWorthy: Bool,
        reasons: [String]
    ) {
        self.lineCount = lineCount
        self.characterCount = characterCount
        self.meanConfidence = meanConfidence
        self.lowConfidenceFraction = lowConfidenceFraction
        self.textCoverage = textCoverage
        self.isScanWorthy = isScanWorthy
        self.reasons = reasons
    }

    public var isLegible: Bool { meanConfidence >= 0.5 && lowConfidenceFraction < 0.5 }
}

/// Which engine produced the result.
public enum EngineRoute: String, Sendable, Codable {
    case rulesOnly
    case onDeviceModel
}

/// Everything the review flow needs from one scan.
public struct EventUnderstandingResult: Sendable, Codable {
    public static let schemaVersion = 1

    public var events: [EventUnderstanding]
    public var quality: OCRQualityReport
    public var route: EngineRoute
    /// Why the on-device model did not run (or why its output was discarded), when `route == .rulesOnly`.
    public var fallbackReason: String?
    public var evidence: [EvidenceLine]
    /// Validator rejections, recorded for observability (counts only are logged).
    public var rejectedFieldCount: Int

    public init(
        events: [EventUnderstanding],
        quality: OCRQualityReport,
        route: EngineRoute,
        fallbackReason: String? = nil,
        evidence: [EvidenceLine] = [],
        rejectedFieldCount: Int = 0
    ) {
        self.events = events
        self.quality = quality
        self.route = route
        self.fallbackReason = fallbackReason
        self.evidence = evidence
        self.rejectedFieldCount = rejectedFieldCount
    }

    public func evidenceLine(_ id: Int) -> EvidenceLine? {
        evidence.first { $0.id == id }
    }
}
