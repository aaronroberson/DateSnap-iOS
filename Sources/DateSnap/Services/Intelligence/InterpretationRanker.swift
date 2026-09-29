import Foundation

// MARK: - Interpretation Ranker & Question Selector
/// Builds the review bundle for one event: picks the best interpretation, keeps only alternatives that
/// change a material field, and asks a question only when that choice changes the saved event.
public enum InterpretationRanker {
    /// At most this many alternatives are shown beside the best interpretation.
    public static let maxAlternatives = 2

    /// Deterministic alternatives: swapped month/day for ambiguous dates, and the runner-up title
    /// when the typography margin is small.
    public static func deterministicAlternatives(
        for candidate: EventInterpretationCandidate,
        titleCandidates: [(text: String, score: Float)],
        calendar: Calendar = .current
    ) -> [EventInterpretationCandidate] {
        var alternatives: [EventInterpretationCandidate] = []

        if candidate.isAmbiguousDate, let swapped = swapMonthAndDay(candidate.start.value, calendar: calendar) {
            var alt = candidate
            alt.id = candidate.id + "-swapped"
            let shift = swapped.timeIntervalSince(candidate.start.value)
            alt.start = FieldAssessment(value: swapped, provenance: .deterministicRule, evidence: candidate.start.evidence,
                                        score: candidate.start.score, isAmbiguous: true,
                                        reason: "Reading \(candidate.ambiguousFragment ?? "the date") as day/month instead.")
            alt.end.value = candidate.end.value?.addingTimeInterval(shift)
            alt.doorsTime = candidate.doorsTime?.addingTimeInterval(shift)
            alt.explanations = [alt.start.reason ?? ""] + candidate.explanations.dropFirst()
            alternatives.append(alt)
        }

        if titleCandidates.count >= 2,
           titleCandidates[0].score - titleCandidates[1].score < 0.08,
           normalized(titleCandidates[1].text) != normalized(candidate.title.value) {
            var alt = candidate
            alt.id = candidate.id + "-title"
            alt.title = FieldAssessment(value: titleCandidates[1].text, provenance: .deterministicRule,
                                        score: max(0, candidate.title.score - 0.05),
                                        reason: "Almost as prominent as \"\(candidate.title.value)\".")
            alternatives.append(alt)
        }
        return alternatives
    }

    /// Combines the deterministic best with validated model candidates and alternatives.
    /// Explicit, high-confidence baseline fields stay authoritative: a model candidate that contradicts
    /// them is offered as an alternative rather than replacing them.
    public static func rank(
        baseline: EventInterpretationCandidate,
        modelCandidate: EventInterpretationCandidate?,
        deterministicAlternatives: [EventInterpretationCandidate],
        ocrMeanConfidence: Float,
        calendar: Calendar = .current
    ) -> (best: EventInterpretationCandidate, alternatives: [EventInterpretationCandidate]) {
        var pool = [baseline] + deterministicAlternatives
        if let modelCandidate { pool.append(modelCandidate) }

        for index in pool.indices {
            pool[index].rankScore = score(pool[index], against: pool, ocrMeanConfidence: ocrMeanConfidence, calendar: calendar)
        }

        var best = baseline
        if let model = pool.first(where: { $0.id == modelCandidate?.id }) {
            let contradictsExplicitStart = baseline.start.provenance == .explicitText
                && baseline.start.score >= 0.8
                && !calendar.isDate(model.start.value, inSameDayAs: baseline.start.value)
            if !contradictsExplicitStart && model.rankScore >= (pool.first { $0.id == baseline.id }?.rankScore ?? 0) {
                best = model
            }
        }
        best.rankScore = pool.first { $0.id == best.id }?.rankScore ?? best.rankScore

        var alternatives: [EventInterpretationCandidate] = []
        for candidate in pool.sorted(by: { $0.rankScore > $1.rankScore }) where candidate.id != best.id {
            guard isMateriallyDifferent(candidate, from: best, calendar: calendar),
                  !alternatives.contains(where: { !isMateriallyDifferent($0, from: candidate, calendar: calendar) }) else { continue }
            alternatives.append(candidate)
            if alternatives.count == maxAlternatives { break }
        }
        return (best, alternatives)
    }

    /// Evidence strength, OCR quality and agreement with the other candidates — never model self-reports.
    static func score(
        _ candidate: EventInterpretationCandidate,
        against pool: [EventInterpretationCandidate],
        ocrMeanConfidence: Float,
        calendar: Calendar
    ) -> Float {
        let fields: [(Float, Float)] = [
            (candidate.start.score, 0.45),
            (candidate.title.score, 0.30),
            (max(candidate.venue.score, candidate.address.score), 0.15),
            (candidate.end.score, 0.10)
        ]
        let evidence = fields.reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let others = pool.filter { $0.id != candidate.id }
        let agreement: Float = others.isEmpty ? 1 : Float(others.filter {
            calendar.isDate($0.start.value, inSameDayAs: candidate.start.value)
                && normalized($0.title.value) == normalized(candidate.title.value)
        }.count) / Float(others.count)
        let ambiguityPenalty: Float = candidate.start.isAmbiguous ? 0.1 : 0
        let groundedBonus: Float = candidate.title.evidence.isEmpty ? 0 : 0.03
        return max(0, min(1, 0.75 * evidence + 0.1 * ocrMeanConfidence + 0.1 * agreement + groundedBonus - ambiguityPenalty))
    }

    public static func isMateriallyDifferent(
        _ a: EventInterpretationCandidate,
        from b: EventInterpretationCandidate,
        calendar: Calendar = .current
    ) -> Bool {
        if !calendar.isDate(a.start.value, inSameDayAs: b.start.value) { return true }
        if abs(a.start.value.timeIntervalSince(b.start.value)) >= 15 * 60 { return true }
        if normalized(a.title.value) != normalized(b.title.value) { return true }
        if normalized(a.venue.value ?? "") != normalized(b.venue.value ?? "") && a.venue.value != nil && b.venue.value != nil { return true }
        return false
    }

    /// One question per materially different field between the best interpretation and its alternatives.
    public static func questions(
        best: EventInterpretationCandidate,
        alternatives: [EventInterpretationCandidate],
        calendar: Calendar = .current
    ) -> [AmbiguityQuestion] {
        var questions: [AmbiguityQuestion] = []
        let dateStyle = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        let timeStyle = Date.FormatStyle.dateTime.hour().minute()

        let dateAlternatives = alternatives.filter { !calendar.isDate($0.start.value, inSameDayAs: best.start.value) }
        if !dateAlternatives.isEmpty {
            questions.append(AmbiguityQuestion(
                field: .date,
                prompt: best.isAmbiguousDate ? "Which date does \(best.ambiguousFragment ?? "the flyer") mean?" : "Which date is the event?",
                options: ([best] + dateAlternatives).map {
                    AmbiguityQuestion.Option(label: $0.start.value.formatted(dateStyle), candidateID: $0.id)
                }
            ))
        }

        let timeAlternatives = alternatives.filter {
            calendar.isDate($0.start.value, inSameDayAs: best.start.value)
                && abs($0.start.value.timeIntervalSince(best.start.value)) >= 15 * 60
        }
        if !timeAlternatives.isEmpty {
            questions.append(AmbiguityQuestion(
                field: .startTime,
                prompt: "When does it start?",
                options: ([best] + timeAlternatives).map {
                    AmbiguityQuestion.Option(label: $0.start.value.formatted(timeStyle), candidateID: $0.id)
                }
            ))
        }

        let titleAlternatives = alternatives.filter {
            calendar.isDate($0.start.value, inSameDayAs: best.start.value) && normalized($0.title.value) != normalized(best.title.value)
        }
        if !titleAlternatives.isEmpty && (best.title.score < 0.8 || best.title.provenance != .modelInterpretation) {
            questions.append(AmbiguityQuestion(
                field: .title,
                prompt: "What's the event called?",
                options: ([best] + titleAlternatives).map { AmbiguityQuestion.Option(label: $0.title.value, candidateID: $0.id) }
            ))
        }
        return questions
    }

    static func swapMonthAndDay(_ date: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let month = comps.month, let day = comps.day, day <= 12, day != month else { return nil }
        comps.month = day
        comps.day = month
        return calendar.date(from: comps)
    }

    static func normalized(_ text: String) -> String {
        DateInference.normalizeText(text).split(separator: " ").joined(separator: " ")
    }
}
