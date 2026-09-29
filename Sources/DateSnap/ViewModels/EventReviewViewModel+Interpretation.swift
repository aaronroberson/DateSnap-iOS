import Foundation
import SwiftData

// MARK: - Interpretation Review
/// Alternatives, questions, provenance, suggestions and duplicate checks for the review form.
extension EventReviewViewModel {
    /// Editable fields whose provenance is shown in review.
    public enum ReviewField: String, CaseIterable, Sendable {
        case title, date, venue, end
    }

    public var appliedInterpretation: EventInterpretationCandidate? {
        guard let understanding else { return nil }
        return understanding.allCandidates.first { $0.id == appliedInterpretationID } ?? understanding.best
    }

    /// Alternatives other than the one currently applied, materially different from it.
    public var visibleAlternatives: [EventInterpretationCandidate] {
        guard let understanding, let applied = appliedInterpretation else { return [] }
        return understanding.allCandidates.filter { $0.id != applied.id }
    }

    /// Fills the editable fields from an interpretation. Doesn't save anything.
    public func apply(_ interpretation: EventInterpretationCandidate) {
        title = interpretation.title.value
        let length = max(endDate.timeIntervalSince(startDate), 0)
        startDate = interpretation.start.value
        endDate = interpretation.end.value ?? startDate.addingTimeInterval(length == 0 ? EventDurationPolicy.fallback : length)
        isAllDay = interpretation.isAllDay
        venueName = interpretation.venue.value ?? ""
        location = interpretation.address.value ?? ""
        notes = interpretation.notesSummary
        category = interpretation.category
        isAmbiguousDate = interpretation.start.isAmbiguous && interpretation.isAmbiguousDate
        ambiguousFragment = isAmbiguousDate ? interpretation.ambiguousFragment : nil
        appliedInterpretationID = interpretation.id
        candidate.interpretation?.selectedInterpretationID = interpretation.id
    }

    /// One-tap answer: applies the chosen interpretation and closes the question.
    public func answer(_ question: AmbiguityQuestion, with option: AmbiguityQuestion.Option) {
        if let chosen = understanding?.allCandidates.first(where: { $0.id == option.candidateID }) {
            apply(chosen)
        }
        openQuestions.removeAll { $0.id == question.id }
        if question.field == .date {
            isAmbiguousDate = false
            ambiguousFragment = nil
        }
    }

    /// Source of a field for the "Confirmed from flyer" / "Inferred" / "Please check" / "Edited" labels.
    public func provenance(for field: ReviewField) -> (provenance: FieldProvenance, needsCheck: Bool)? {
        guard let applied = appliedInterpretation else { return nil }
        if isEdited(field, from: applied) { return (.userEdited, false) }
        switch field {
        case .title: return (applied.title.provenance, applied.title.score < 0.6)
        case .date: return (applied.start.provenance, isAmbiguousDate || yearAssumed)
        case .venue:
            guard applied.venue.value != nil || applied.address.value != nil else { return nil }
            return (applied.venue.value != nil ? applied.venue.provenance : applied.address.provenance, false)
        case .end:
            guard !isAllDay else { return nil }
            return (applied.end.provenance, applied.end.provenance == .fallbackDefault)
        }
    }

    func isEdited(_ field: ReviewField, from applied: EventInterpretationCandidate) -> Bool {
        switch field {
        case .title: return title != applied.title.value
        case .date: return abs(startDate.timeIntervalSince(applied.start.value)) >= 60
        case .venue: return venueName != (applied.venue.value ?? "") || location != (applied.address.value ?? "")
        case .end:
            guard let end = applied.end.value else { return false }
            return abs(endDate.timeIntervalSince(end)) >= 60
        }
    }

    /// Records which fields the user changed from the applied interpretation (field names only).
    func recordCorrections() {
        guard let applied = appliedInterpretation, let record = candidate.interpretation else { return }
        let edited = ReviewField.allCases.filter { isEdited($0, from: applied) }.map(\.rawValue)
        for field in edited where !record.correctedFields.contains(field) {
            IntelligenceTelemetry.recordEdit(field: field)
        }
        record.correctedFields = Array(Set(record.correctedFields + edited)).sorted()
    }

    /// "Why this?" rows: a field label, its reason, and the source line text when there is one.
    public var whyThisRows: [(field: String, reason: String, source: String?)] {
        guard let applied = appliedInterpretation else { return [] }
        func source(_ refs: [EvidenceReference]) -> String? {
            refs.first.flatMap { ref in evidenceLines.first { $0.id == ref.lineID }?.text }
        }
        var rows: [(String, String, String?)] = []
        if let reason = applied.title.reason { rows.append(("Title", reason, source(applied.title.evidence))) }
        if let reason = applied.start.reason { rows.append(("Date & time", reason, source(applied.start.evidence))) }
        if let reason = applied.venue.reason, applied.venue.value != nil { rows.append(("Venue", reason, source(applied.venue.evidence))) }
        if let reason = applied.end.reason, !isAllDay { rows.append(("End", reason, nil)) }
        for extra in applied.explanations { rows.append(("Note", extra, nil)) }
        return rows
    }

    // MARK: Suggestions

    /// Category-based length suggestion when the flyer has no end time.
    public var suggestedDuration: TimeInterval? {
        guard !isAllDay, appliedInterpretation?.end.provenance == .fallbackDefault,
              let suggestion = EventDurationPolicy.suggestedDuration(for: category),
              abs(endDate.timeIntervalSince(startDate) - suggestion) >= 60 else { return nil }
        return suggestion
    }

    public func applySuggestedDuration() {
        guard let duration = suggestedDuration else { return }
        endDate = startDate.addingTimeInterval(duration)
    }

    public var reminderPlan: ReminderPlan {
        ReminderStrategyService.plan(category: category, start: startDate, isAllDay: isAllDay, rsvpDeadline: rsvpDeadline)
    }

    public func applyReminderPlan() {
        selectedOffsets = reminderPlan.offsets
    }

    /// When the accepted deadline reminder will fire.
    public var deadlineReminderDate: Date? { reminderPlan.deadlineReminder }

    public var actions: [ActionSuggestion] { understanding?.actions ?? [] }
    public var recurrenceSignal: RecurrenceSignal? { understanding?.recurrence }

    // MARK: Duplicates

    /// Looks for other events (saved or pending) that may be this event from another screenshot.
    public func findDuplicates(in context: ModelContext) {
        let key = candidate.similarityKey.isEmpty
            ? RuleBasedEventAnalyzer.similarityKey(title: title, start: startDate, venue: venueName.isEmpty ? location : venueName)
            : candidate.similarityKey
        let me = EventSimilarityService.Entry(id: candidate.id, similarityKey: key, title: title, start: startDate, isSaved: false)
        let dayStart = Calendar.current.startOfDay(for: startDate)
        let dayEnd = dayStart.addingTimeInterval(86400)
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.startDate >= dayStart && $0.startDate < dayEnd })
        let sameDay = (try? context.fetch(descriptor)) ?? []
        let entries = sameDay.map {
            EventSimilarityService.Entry(id: $0.id, similarityKey: $0.similarityKey, title: $0.title, start: $0.startDate,
                                         isSaved: $0.savedEvent?.status == .saved)
        }
        duplicateMatches = EventSimilarityService.matches(for: me, among: entries).filter { $0.entry.isSaved }
    }
}
