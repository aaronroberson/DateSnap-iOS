import Foundation

// MARK: - Interpreter Contract

/// Bounded, value-only input for the on-device interpreter. Contains OCR lines — never images, SwiftData
/// models, Calendar contents or the photo library.
public struct InterpretationRequest: Sendable {
    public var lines: [EvidenceLine]
    public var referenceDate: Date
    public var localeIdentifier: String
    public var timeZoneIdentifier: String
    /// The deterministic interpretation(s), so the model can confirm or re-label rather than start over.
    public var baseline: [EventInterpretationCandidate]
    public var triggers: [String]

    public init(lines: [EvidenceLine], referenceDate: Date, localeIdentifier: String, timeZoneIdentifier: String,
                baseline: [EventInterpretationCandidate], triggers: [String]) {
        self.lines = lines
        self.referenceDate = referenceDate
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.baseline = baseline
        self.triggers = triggers
    }

    /// Trims the request to the policy's line and character limits, keeping reading order.
    public func bounded(by policy: IntelligencePolicy) -> InterpretationRequest {
        var kept: [EvidenceLine] = []
        var characters = 0
        for line in lines.prefix(policy.maxInputLines) {
            let text = String(line.text.prefix(200))
            guard characters + text.count <= policy.maxInputCharacters else { break }
            characters += text.count
            var trimmed = line
            trimmed.text = text
            kept.append(trimmed)
        }
        var copy = self
        copy.lines = kept
        return copy
    }
}

/// What the model proposes for one event. Every value must point at an OCR line; free text is only
/// accepted when it is contained in the referenced line.
public struct EventHypothesis: Sendable, Codable, Equatable {
    public var titleLineID: Int?
    public var titleText: String?
    public var venueLineID: Int?
    public var venueText: String?
    public var organizerLineID: Int?
    public var organizerText: String?
    public var performerLineID: Int?
    public var performerText: String?
    /// Line that states the event's date.
    public var dateLineID: Int?
    /// Line and exact text of the event start time (the show, not the doors).
    public var startTimeLineID: Int?
    public var startTimeText: String?
    public var doorsTimeLineID: Int?
    public var doorsTimeText: String?
    public var endTimeLineID: Int?
    public var endTimeText: String?
    public var category: String?
    public var notesSummary: String?
    /// One short observable reason, e.g. "Show time is labeled 'Show'".
    public var reason: String?

    public init(
        titleLineID: Int? = nil, titleText: String? = nil,
        venueLineID: Int? = nil, venueText: String? = nil,
        organizerLineID: Int? = nil, organizerText: String? = nil,
        performerLineID: Int? = nil, performerText: String? = nil,
        dateLineID: Int? = nil,
        startTimeLineID: Int? = nil, startTimeText: String? = nil,
        doorsTimeLineID: Int? = nil, doorsTimeText: String? = nil,
        endTimeLineID: Int? = nil, endTimeText: String? = nil,
        category: String? = nil, notesSummary: String? = nil, reason: String? = nil
    ) {
        self.titleLineID = titleLineID
        self.titleText = titleText
        self.venueLineID = venueLineID
        self.venueText = venueText
        self.organizerLineID = organizerLineID
        self.organizerText = organizerText
        self.performerLineID = performerLineID
        self.performerText = performerText
        self.dateLineID = dateLineID
        self.startTimeLineID = startTimeLineID
        self.startTimeText = startTimeText
        self.doorsTimeLineID = doorsTimeLineID
        self.doorsTimeText = doorsTimeText
        self.endTimeLineID = endTimeLineID
        self.endTimeText = endTimeText
        self.category = category
        self.notesSummary = notesSummary
        self.reason = reason
    }
}

/// On-device semantic interpreter. Implementations must be side-effect free.
public protocol OnDeviceEventInterpreting: Sendable {
    func interpret(_ request: InterpretationRequest) async throws -> [EventHypothesis]
    /// Optional warm-up so the first request doesn't pay model load time.
    func prewarm() async
}

extension OnDeviceEventInterpreting {
    public func prewarm() async {}
}

// MARK: - Evidence Validator

/// Checks every model-proposed value against the OCR evidence and merges accepted values into a copy
/// of the deterministic candidate. Unsupported dates, times, entities and categories are rejected.
public enum EvidenceValidator {

    public struct Outcome: Sendable {
        /// The merged candidate, or nil if nothing in the hypothesis survived validation.
        public var candidate: EventInterpretationCandidate?
        public var acceptedFields: [String]
        public var rejectedFields: [String]
    }

    public static func validate(
        _ hypothesis: EventHypothesis,
        against baseline: EventInterpretationCandidate,
        evidence: [EvidenceLine],
        locale: Locale,
        anchor: Date,
        calendar: Calendar = .current
    ) -> Outcome {
        var candidate = baseline
        candidate.id = baseline.id + "-model"
        var accepted: [String] = []
        var rejected: [String] = []
        var explanations: [String] = []

        func line(_ id: Int?) -> EvidenceLine? {
            guard let id else { return nil }
            return evidence.first { $0.id == id }
        }

        /// Accepts `text` only if it appears in the referenced line; returns the line's own spelling.
        func grounded(_ text: String?, in lineID: Int?, field: String) -> (String, EvidenceLine)? {
            guard lineID != nil || text != nil else { return nil }
            guard let source = line(lineID) else { rejected.append(field); return nil }
            let value = (text ?? source.text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count >= 2, value.count <= 120,
                  let range = source.text.range(of: value, options: [.caseInsensitive, .diacriticInsensitive]) else {
                rejected.append(field)
                return nil
            }
            return (String(source.text[range]), source)
        }

        func reference(_ line: EvidenceLine) -> [EvidenceReference] {
            [EvidenceReference(lineID: line.id, confidence: line.confidence)]
        }

        // Title / venue / organizer / performer: labels over existing lines only.
        if let (title, source) = grounded(hypothesis.titleText, in: hypothesis.titleLineID, field: "title") {
            candidate.title = FieldAssessment(value: title, provenance: .modelInterpretation, evidence: reference(source),
                                              score: min(0.95, 0.7 + 0.25 * source.confidence),
                                              reason: "Title from \"\(source.text)\".")
            accepted.append("title")
        }
        if let (venue, source) = grounded(hypothesis.venueText, in: hypothesis.venueLineID, field: "venue") {
            candidate.venue = FieldAssessment(value: venue, provenance: .modelInterpretation, evidence: reference(source),
                                              score: min(0.9, 0.65 + 0.25 * source.confidence),
                                              reason: "Venue from \"\(source.text)\".")
            accepted.append("venue")
        }
        // An organizer or performer on the title (or venue) line is a role collision, not a new entity.
        let titleLine = hypothesis.titleLineID
        let venueLine = hypothesis.venueLineID
        var hypothesis = hypothesis
        for (lineID, field) in [(hypothesis.organizerLineID, "organizer"), (hypothesis.performerLineID, "performer")] {
            guard let lineID, lineID == titleLine || lineID == venueLine else { continue }
            rejected.append(field)
            if field == "organizer" { hypothesis.organizerLineID = nil; hypothesis.organizerText = nil }
            else { hypothesis.performerLineID = nil; hypothesis.performerText = nil }
        }
        if let (organizer, source) = grounded(hypothesis.organizerText, in: hypothesis.organizerLineID, field: "organizer") {
            candidate.organizer = FieldAssessment(value: organizer, provenance: .modelInterpretation, evidence: reference(source), score: 0.75)
            accepted.append("organizer")
        }
        if let (performer, source) = grounded(hypothesis.performerText, in: hypothesis.performerLineID, field: "performer") {
            candidate.performer = FieldAssessment(value: performer, provenance: .modelInterpretation, evidence: reference(source), score: 0.7)
            accepted.append("performer")
        }

        // Date: must be parseable from the referenced line by the deterministic detector.
        var day = baseline.start.value
        var dateEvidence = baseline.start.evidence
        if let dateLineID = hypothesis.dateLineID {
            if let source = line(dateLineID),
               let detected = DateInference.detectDates(in: source.text, locale: locale, anchor: anchor, calendar: calendar).first {
                day = detected.startDate
                dateEvidence = reference(source)
                if !calendar.isDate(day, inSameDayAs: baseline.start.value) { accepted.append("date") }
            } else {
                rejected.append("date")
            }
        }

        // Times: the exact text must appear in its line and parse to a valid clock time.
        func time(_ text: String?, lineID: Int?, field: String) -> (hour: Int, minute: Int, line: EvidenceLine)? {
            guard let text else { return nil }
            guard let (raw, source) = grounded(text, in: lineID, field: field),
                  let parsed = DateInference.parseSingleTime(raw) else {
                if !rejected.contains(field) { rejected.append(field) }
                return nil
            }
            return (parsed.hour, parsed.minute, source)
        }

        var startTime = time(hypothesis.startTimeText, lineID: hypothesis.startTimeLineID, field: "startTime")
        // A start on a doors/opening line loses to an explicitly show-labeled time elsewhere on the flyer.
        if let proposed = startTime,
           RuleBasedEventAnalyzer.role(forLine: proposed.line.text.lowercased()) == .doors,
           evidence.contains(where: { $0.id != proposed.line.id && RuleBasedEventAnalyzer.role(forLine: $0.text.lowercased()) == .show }) {
            startTime = nil
            rejected.append("startTime")
        }
        let doorsTime = time(hypothesis.doorsTimeText, lineID: hypothesis.doorsTimeLineID, field: "doorsTime")
        let endTime = time(hypothesis.endTimeText, lineID: hypothesis.endTimeLineID, field: "endTime")

        let baselineComps = calendar.dateComponents([.hour, .minute], from: baseline.start.value)
        let hour = startTime?.hour ?? baselineComps.hour ?? 0
        let minute = startTime?.minute ?? baselineComps.minute ?? 0
        let start = candidate.isAllDay && startTime == nil
            ? calendar.startOfDay(for: day)
            : (calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day)

        if startTime != nil || hypothesis.dateLineID != nil {
            var evidenceRefs = dateEvidence
            if let startTime { evidenceRefs += reference(startTime.line) }
            candidate.start = FieldAssessment(
                value: start,
                provenance: .modelInterpretation,
                evidence: evidenceRefs,
                score: min(0.95, 0.6 + 0.3 * (startTime?.line.confidence ?? baseline.start.score)),
                isAmbiguous: baseline.isAmbiguousDate && hypothesis.dateLineID == nil,
                reason: startTime.map { "Start time taken from \"\($0.line.text)\"." } ?? baseline.start.reason
            )
            if startTime != nil {
                accepted.append("startTime")
                candidate.isAllDay = false
            }
        }

        if let doorsTime {
            candidate.doorsTime = calendar.date(bySettingHour: doorsTime.hour, minute: doorsTime.minute, second: 0, of: day)
            if let doors = candidate.doorsTime, doors >= start {
                // Doors at or after the start contradicts the labels; drop the doors value rather than guess.
                candidate.doorsTime = baseline.doorsTime
                rejected.append("doorsTime")
            } else {
                accepted.append("doorsTime")
            }
        }

        // End: explicit, after start (an end earlier than the start rolls to the next day, up to 12 h).
        if let endTime, var end = calendar.date(bySettingHour: endTime.hour, minute: endTime.minute, second: 0, of: day) {
            if end <= start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
            if end.timeIntervalSince(start) <= 12 * 3600 {
                candidate.end = FieldAssessment(value: end, provenance: .modelInterpretation,
                                                evidence: reference(endTime.line), score: 0.8)
                candidate.durationSource = .explicit
                accepted.append("endTime")
            } else {
                rejected.append("endTime")
            }
        } else if accepted.contains("startTime") || accepted.contains("date"),
                  candidate.end.provenance != .explicitText || candidate.end.value.map({ $0 <= start }) == true {
            // Keep the baseline's length relative to the new start.
            let length = baseline.end.value.map { $0.timeIntervalSince(baseline.start.value) } ?? EventDurationPolicy.fallback
            candidate.end.value = candidate.isAllDay ? nil : start.addingTimeInterval(max(length, 0))
        }

        if let raw = hypothesis.category {
            if let category = EventCategory(rawValue: raw) {
                candidate.category = category
                if candidate.durationSource != .explicit {
                    candidate.durationSource = EventDurationPolicy.suggestedDuration(for: category) != nil ? .categoryDefault : .fallback
                }
                accepted.append("category")
            } else {
                rejected.append("category")
            }
        }

        if let summary = hypothesis.notesSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            // Summaries may not introduce links, emails or phone numbers that the flyer lacks.
            let introducesContact = summary.range(of: "https?://|www\\.|@|\\d{3}[-. ]\\d{3}[-. ]\\d{4}", options: .regularExpression) != nil
            // Every substantive word must appear on the flyer, so the model can condense but not invent.
            let flyerWords = Set(evidence.flatMap { $0.text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) })
            let summaryWords = summary.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 }
            let grounded = summaryWords.allSatisfy { flyerWords.contains($0) }
            if summary.count <= 240 && !introducesContact && grounded {
                candidate.notesSummary = [baseline.notesSummary, summary].filter { !$0.isEmpty }.joined(separator: " · ")
                accepted.append("notes")
            } else {
                rejected.append("notes")
            }
        }

        // Keep only a readable sentence from the model; field names or fragments are dropped.
        if let reason = hypothesis.reason?.trimmingCharacters(in: .whitespacesAndNewlines),
           reason.count >= 12, reason.count <= 160, reason.contains(" ") {
            explanations.append("On-device model: \(reason)")
        }
        if startTime != nil, let doors = candidate.doorsTime {
            candidate.start.reason = (candidate.start.reason ?? "") + " Doors at \(doors.formatted(date: .omitted, time: .shortened)) kept in notes."
        }

        guard !accepted.isEmpty else {
            return Outcome(candidate: nil, acceptedFields: [], rejectedFields: rejected)
        }
        candidate.explanations = explanations
        candidate.similarityKey = RuleBasedEventAnalyzer.similarityKey(
            title: candidate.title.value, start: candidate.start.value,
            venue: candidate.venue.value ?? candidate.address.value, calendar: calendar
        )
        return Outcome(candidate: candidate, acceptedFields: accepted, rejectedFields: rejected)
    }
}
