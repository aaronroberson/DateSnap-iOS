import Foundation
import CoreGraphics

// MARK: - Rule-Based Event Analyzer
/// Deterministic first stage of event understanding. Builds the evidence map and scan-quality report,
/// classifies every temporal fragment by role, finds actions, recurrence and category signals, and
/// converts parser candidates into evidence-linked interpretations. Works on every supported device.
public enum RuleBasedEventAnalyzer {

    public struct Analysis: Sendable {
        public var events: [EventUnderstanding]
        public var quality: OCRQualityReport
        public var evidence: [EvidenceLine]
        /// Reasons a semantic pass could help; empty when the deterministic result is clear.
        public var triggers: [String]
        /// Runner-up title lines (text, score), best first, for alternatives.
        public var titleCandidates: [(text: String, score: Float)]
    }

    public static func analyze(
        result: OCRResult,
        extracted: [ExtractedCandidateData],
        locale: Locale,
        anchor: Date,
        calendar: Calendar = .current
    ) -> Analysis {
        let evidence = buildEvidenceMap(from: result)
        let quality = qualityReport(for: result, anchor: anchor)
        let temporal = classifyTemporalEvidence(in: evidence, locale: locale, anchor: anchor)
        let actions = extractActions(in: evidence, temporal: temporal)
        let recurrence = detectRecurrence(in: evidence)
        let fullText = result.fullText
        let category = classifyCategory(text: fullText)
        let titleRanking = DateInference.rankTitleCandidates(lines: result.lines).map { (text: $0.line.text, score: $0.score) }

        let events = extracted.map { dto -> EventUnderstanding in
            let candidate = baselineCandidate(
                from: dto,
                evidence: evidence,
                temporal: temporal,
                category: category,
                meanOCRConfidence: quality.meanConfidence,
                calendar: calendar
            )
            return EventUnderstanding(
                best: candidate,
                actions: actions,
                recurrence: recurrence,
                temporalEvidence: temporal
            )
        }

        let triggers = semanticTriggers(
            extracted: extracted,
            temporal: temporal,
            titleRanking: titleRanking,
            quality: quality,
            calendar: calendar
        )

        return Analysis(events: events, quality: quality, evidence: evidence, triggers: triggers, titleCandidates: titleRanking)
    }

    // MARK: - Evidence Map

    /// Stable line IDs in reading order, block IDs from parser segmentation, and a font-size rank.
    public static func buildEvidenceMap(from result: OCRResult) -> [EvidenceLine] {
        var blockIndexByLine: [UUID: Int] = [:]
        for (blockIndex, block) in DateInference.segmentIntoEventBlocks(result: result).enumerated() {
            for line in block.lines { blockIndexByLine[line.id] = blockIndex }
        }
        let sizeOrder = result.lines.map(\.fontSizeProxy).sorted(by: >)
        return result.lines.enumerated().map { index, line in
            EvidenceLine(
                id: index,
                blockID: blockIndexByLine[line.id] ?? 0,
                text: line.text,
                confidence: line.confidence,
                boundingBox: line.boundingBox,
                fontRank: sizeOrder.firstIndex(of: line.fontSizeProxy) ?? index
            )
        }
    }

    /// Lines whose text contains `value` (or is contained by it), for linking a field to its source.
    public static func references(for value: String?, in evidence: [EvidenceLine]) -> [EvidenceReference] {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.count >= 2 else { return [] }
        let needle = value.lowercased()
        return evidence
            .filter { line in
                let hay = line.text.lowercased()
                return hay.contains(needle) || (needle.contains(hay) && hay.count >= 4)
            }
            .map { EvidenceReference(lineID: $0.id, confidence: $0.confidence) }
    }

    // MARK: - Scan Quality

    public static func qualityReport(for result: OCRResult, anchor: Date) -> OCRQualityReport {
        let lines = result.lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let characters = lines.reduce(0) { $0 + $1.text.count }
        let mean = lines.isEmpty ? 0 : lines.reduce(Float(0)) { $0 + $1.confidence } / Float(lines.count)
        let low = lines.isEmpty ? 0 : Float(lines.filter { $0.confidence < 0.5 }.count) / Float(lines.count)
        let coverage = min(1, lines.reduce(CGFloat(0)) { $0 + max(0, $1.boundingBox.width * $1.boundingBox.height) })

        var reasons: [String] = []
        let text = result.fullText
        let hasTemporalCue = containsTemporalCue(text)
        if lines.isEmpty { reasons.append("noText") }
        if !hasTemporalCue { reasons.append("noDateOrTimeCue") }
        let rejected = !text.isEmpty && DateInference.isFalsePositive(text: text, anchor: anchor)
        if rejected { reasons.append("receiptOrNotice") }
        if mean < 0.5 && !lines.isEmpty { reasons.append("lowRecognitionConfidence") }

        return OCRQualityReport(
            lineCount: lines.count,
            characterCount: characters,
            meanConfidence: mean,
            lowConfidenceFraction: low,
            textCoverage: Float(coverage),
            isScanWorthy: !lines.isEmpty && hasTemporalCue && !rejected,
            reasons: reasons
        )
    }

    private static let monthPattern = "\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\.?\\b"
    private static let timePattern = "(?<![\\d/.:])(\\d{1,2}:\\d{2}\\s*(?:am|pm)?|\\d{1,2}\\s*(?:am|pm)|noon|midnight)"
    private static let numericDatePattern = "\\b\\d{1,2}[/.-]\\d{1,2}(?:[/.-]\\d{2,4})?\\b"
    private static let relativePattern = "\\b(today|tonight|tomorrow|this (mon|tues|wednes|thurs|fri|satur|sun)day|next (week|mon|tues|wednes|thurs|fri|satur|sun))"

    static func containsTemporalCue(_ text: String) -> Bool {
        let lower = text.lowercased()
        return [monthPattern, timePattern, numericDatePattern, relativePattern].contains { pattern in
            lower.range(of: pattern, options: .regularExpression) != nil
        }
    }

    // MARK: - Temporal Evidence

    /// Every date/time fragment with a role inferred from its own line's labels.
    public static func classifyTemporalEvidence(in evidence: [EvidenceLine], locale: Locale, anchor: Date) -> [TemporalEvidence] {
        guard let timeRegex = try? NSRegularExpression(pattern: timePattern, options: [.caseInsensitive]) else { return [] }
        var found: [TemporalEvidence] = []

        for line in evidence {
            let text = line.text
            let lower = text.lowercased()
            let lineRole = role(forLine: lower)

            // Dates on this line
            let dates = DateInference.detectDates(in: text, locale: locale, anchor: anchor)
            if let first = dates.first, containsDateCue(lower) {
                let dateRole: TemporalRole = (lineRole == .rsvpDeadline || lineRole == .ticketSale) ? (lineRole ?? .eventDate) : .eventDate
                found.append(TemporalEvidence(fragment: text, role: dateRole, lineID: line.id, date: first.startDate))
            }

            // Times on this line, each labeled by the marker immediately before it when present
            let ns = text as NSString
            for match in timeRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range(at: 1))
                guard let time = DateInference.parseSingleTime(raw) else { continue }
                let prefixStart = max(0, match.range.location - 14)
                let prefix = ns.substring(with: NSRange(location: prefixStart, length: match.range.location - prefixStart)).lowercased()
                let timeRole = role(forTimePrefix: prefix) ?? lineRole ?? .other
                found.append(TemporalEvidence(fragment: raw, role: timeRole, lineID: line.id, hour: time.hour, minute: time.minute))
            }
        }
        return found
    }

    private static func containsDateCue(_ lower: String) -> Bool {
        [monthPattern, numericDatePattern, relativePattern].contains { lower.range(of: $0, options: .regularExpression) != nil }
    }

    static func role(forLine lower: String) -> TemporalRole? {
        if ["rsvp by", "rsvp before", "register by", "registration closes", "reply by", "sign up by", "deadline", "rsvp no later"].contains(where: lower.contains) {
            return .rsvpDeadline
        }
        if ["on sale", "presale", "pre-sale", "tickets available"].contains(where: lower.contains) { return .ticketSale }
        if lower.contains("door") { return .doors }
        if lower.range(of: "\\b(show|showtime|starts?|begins?|kick ?off)\\b", options: .regularExpression) != nil { return .show }
        if lower.range(of: "\\b(until|till|til|ends?|curfew|close)\\b", options: .regularExpression) != nil { return .eventEnd }
        return nil
    }

    private static func role(forTimePrefix prefix: String) -> TemporalRole? {
        if prefix.range(of: "doors?( open)?\\s*(@|at)?\\s*$", options: .regularExpression) != nil { return .doors }
        if prefix.range(of: "(show|showtime|starts?|begins?)\\s*(@|at)?\\s*$", options: .regularExpression) != nil { return .show }
        if prefix.range(of: "(until|till|til|to|-|–|—|ends?|curfew)\\s*$", options: .regularExpression) != nil { return .eventEnd }
        return nil
    }

    // MARK: - Actions

    /// RSVP / tickets / registration links, phone numbers and emails, each copied verbatim from a line.
    public static func extractActions(in evidence: [EvidenceLine], temporal: [TemporalEvidence]) -> [ActionSuggestion] {
        let deadline = temporal.first { $0.role == .rsvpDeadline && $0.date != nil }?.date
        let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        var actions: [ActionSuggestion] = []

        for line in evidence {
            let text = line.text
            let lower = text.lowercased()
            let reference = [EvidenceReference(lineID: line.id, confidence: line.confidence)]
            let ns = text as NSString

            // Data detector links, plus scheme-less domains it misses (e.g. newer TLDs like ".app").
            var linkRanges = (linkDetector?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [])
                .filter { $0.url?.scheme != "mailto" }
                .map(\.range)
            if linkRanges.isEmpty, let domainRegex = try? NSRegularExpression(
                pattern: "(?<![@\\w.])(?:https?://)?(?:[a-z0-9-]+\\.)+[a-z]{2,}(?:/[^\\s]*)?", options: [.caseInsensitive]) {
                linkRanges = domainRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map(\.range)
            }
            for range in linkRanges {
                let target = ns.substring(with: range)
                let kind: ActionSuggestion.Kind
                if lower.contains("rsvp") { kind = .rsvp }
                else if lower.contains("ticket") { kind = .buyTickets }
                else if lower.range(of: "regist|sign up|signup", options: .regularExpression) != nil { kind = .register }
                else { kind = .website }
                let needsDeadline = kind == .rsvp || kind == .register
                actions.append(ActionSuggestion(kind: kind, target: target, deadline: needsDeadline ? deadline : nil, evidence: reference))
            }
            if let email = DateInference.extractEmail(from: text) {
                actions.append(ActionSuggestion(kind: lower.contains("rsvp") ? .rsvp : .email, target: email,
                                                deadline: lower.contains("rsvp") ? deadline : nil, evidence: reference))
            }
            if let phone = DateInference.extractPhoneNumber(from: text) {
                actions.append(ActionSuggestion(kind: .call, target: phone, evidence: reference))
            }
        }

        // A deadline with no link still deserves an RSVP action the user can act on manually.
        if let deadline, !actions.contains(where: { $0.kind == .rsvp || $0.kind == .register }),
           let line = temporal.first(where: { $0.role == .rsvpDeadline }) {
            actions.append(ActionSuggestion(kind: .rsvp, target: "", deadline: deadline,
                                            evidence: [EvidenceReference(lineID: line.lineID, confidence: 1)]))
        }

        var seen = Set<String>()
        return actions.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Recurrence

    public static func detectRecurrence(in evidence: [EvidenceLine]) -> RecurrenceSignal? {
        let day = "(mon|tues|wednes|thurs|fri|satur|sun)day"
        let patterns: [(String, RecurrenceSignal.Kind)] = [
            ("\\bevery (other )?\(day)s?\\b", .weekly),
            ("\\b(weekly|every week)\\b", .weekly),
            ("\\b(first|second|third|fourth|last|1st|2nd|3rd|4th) \(day)s?\\b", .monthly),
            ("\\b(monthly|every month)\\b", .monthly),
            ("\\b(vol\\.?|volume|edition|episode|ep\\.|no\\.|#)\\s?\\d{1,3}\\b", .series),
            ("\\bseries\\b", .series)
        ]
        for line in evidence {
            let lower = line.text.lowercased()
            for (pattern, kind) in patterns {
                if let range = lower.range(of: pattern, options: .regularExpression) {
                    return RecurrenceSignal(kind: kind, phrase: String(line.text[range]), lineID: line.id)
                }
            }
        }
        return nil
    }

    // MARK: - Category

    public static func classifyCategory(text: String) -> EventCategory {
        let lower = text.lowercased()
        let rules: [(EventCategory, [String])] = [
            (.appointment, ["appointment", "dds", "dentist", "dr.", "clinic", "checkup", "check-up", "consultation", "reservation for"]),
            (.deadline, ["deadline", "due by", "submit by", "applications close"]),
            (.conference, ["conference", "summit", "keynote", "panel", "talk", "webinar", "meetup", "expo"]),
            (.classOrWorkshop, ["workshop", "class", "course", "lesson", "training", "bootcamp"]),
            (.festival, ["festival", "fest ", "fair"]),
            (.sports, ["vs.", " vs ", "game day", "tipoff", "kickoff", "match", "tournament", "race"]),
            (.concert, ["concert", "live music", "tour", "show", "band", "orchestra", "doors", "tickets"]),
            (.nightlife, ["dj", "club", "rooftop", "party", "21+", "nightlife", "lounge"]),
            (.social, ["mixer", "birthday", "wedding", "dinner", "brunch", "potluck", "networking", "reunion", "meet & greet"])
        ]
        for (category, keywords) in rules where keywords.contains(where: lower.contains) {
            return category
        }
        return .other
    }

    // MARK: - Baseline Interpretation

    static func baselineCandidate(
        from dto: ExtractedCandidateData,
        evidence: [EvidenceLine],
        temporal: [TemporalEvidence],
        category: EventCategory,
        meanOCRConfidence: Float,
        calendar: Calendar
    ) -> EventInterpretationCandidate {
        let fullText = dto.rawTextSnippet
        let timeInfo = DateInference.parseTimesAndWindows(in: fullText)

        let titleRefs = references(for: dto.title, in: evidence)
        let dateRefs = temporal
            .filter { $0.role == .eventDate || $0.role == .show || ($0.role == .other && $0.hour != nil) }
            .map { fragment in
                EvidenceReference(lineID: fragment.lineID, confidence: evidence.first { $0.id == fragment.lineID }?.confidence ?? 0)
            }
        let startProvenance: FieldProvenance = (dto.yearAssumed || dto.isAmbiguousDate) ? .deterministicRule : .explicitText

        var startReason: String
        if let show = temporal.first(where: { $0.role == .show && $0.hour != nil }), timeInfo.doorsHour != nil {
            startReason = "Start time taken from the line marked \"\(lineText(show.lineID, evidence))\"; doors time kept in notes."
        } else if dto.isAmbiguousDate {
            startReason = "\(dto.ambiguousFragment ?? "This date") could be month/day or day/month."
        } else if dto.yearAssumed {
            startReason = "No year on the flyer, so the next upcoming date was used."
        } else {
            startReason = "Date read from the flyer text."
        }

        let hasExplicitEnd = timeInfo.endHour != nil || dto.isAllDay
        let durationSource: DurationSource = hasExplicitEnd ? .explicit : (EventDurationPolicy.suggestedDuration(for: category) != nil ? .categoryDefault : .fallback)
        let endProvenance: FieldProvenance = hasExplicitEnd ? .explicitText : .fallbackDefault

        let venueRefs = references(for: dto.venueName, in: evidence)
        let addressRefs = references(for: dto.location, in: evidence)
        let organizer = entity(after: ["presented by", "hosted by", "organized by", "organised by", "brought to you by"], in: evidence)
        let performer = entity(after: ["featuring", "feat.", "ft.", "music by", "live:", "with special guest", "dj "], in: evidence)

        let tzExplicit = fullText.range(of: "\\b(PST|PDT|EST|EDT|CST|CDT|MST|MDT|GMT|UTC|BST|CET|IST)\\b", options: .regularExpression) != nil

        var explanations: [String] = []
        if let line = titleRefs.first { explanations.append("Title: most prominent line \"\(lineText(line.lineID, evidence))\".") }
        explanations.append(startReason)
        if let venue = dto.venueName, let line = venueRefs.first ?? addressRefs.first {
            explanations.append("Venue \"\(venue)\" read from \"\(lineText(line.lineID, evidence))\".")
        }
        if !hasExplicitEnd && !dto.isAllDay {
            explanations.append("No end time on the flyer; using the standard 2-hour length.")
        }

        let evidenceScore = { (refs: [EvidenceReference], base: Float) -> Float in
            let ocr = refs.isEmpty ? meanOCRConfidence : refs.map(\.confidence).max() ?? meanOCRConfidence
            return max(0, min(1, base * (0.6 + 0.4 * ocr)))
        }

        return EventInterpretationCandidate(
            id: dto.id,
            title: FieldAssessment(value: dto.title, provenance: .deterministicRule, evidence: titleRefs,
                                   score: evidenceScore(titleRefs, dto.titleConfidence), reason: explanations.first),
            start: FieldAssessment(value: dto.startDate, provenance: startProvenance, evidence: dateRefs,
                                   score: evidenceScore(dateRefs, dto.dateConfidence), isAmbiguous: dto.isAmbiguousDate, reason: startReason),
            end: FieldAssessment(value: dto.endDate, provenance: endProvenance, evidence: [],
                                 score: hasExplicitEnd ? 0.9 : 0.4),
            isAllDay: dto.isAllDay,
            venue: FieldAssessment(value: dto.venueName, provenance: .explicitText, evidence: venueRefs,
                                   score: dto.venueName == nil ? 0 : evidenceScore(venueRefs, 0.85)),
            address: FieldAssessment(value: dto.location, provenance: .explicitText, evidence: addressRefs,
                                     score: dto.location == nil ? 0 : evidenceScore(addressRefs, 0.9)),
            organizer: FieldAssessment(value: organizer?.value, provenance: .explicitText,
                                       evidence: organizer.map { [$0.reference] } ?? [], score: organizer == nil ? 0 : 0.8),
            performer: FieldAssessment(value: performer?.value, provenance: .explicitText,
                                       evidence: performer.map { [$0.reference] } ?? [], score: performer == nil ? 0 : 0.7),
            doorsTime: doorsDate(timeInfo: timeInfo, on: dto.startDate, calendar: calendar),
            category: category,
            durationSource: durationSource,
            timeZoneIdentifier: dto.timeZoneIdentifier,
            timeZoneSource: tzExplicit ? .explicit : .deviceLocal,
            notesSummary: notesSummary(base: dto.notes, evidence: evidence),
            yearAssumed: dto.yearAssumed,
            isAmbiguousDate: dto.isAmbiguousDate,
            ambiguousFragment: dto.ambiguousFragment,
            rsvpUrl: dto.rsvpUrl,
            phoneNumber: dto.phoneNumber,
            email: dto.email,
            rawSnippet: dto.rawTextSnippet,
            dedupeKey: dto.dedupeKey,
            similarityKey: similarityKey(title: dto.title, start: dto.startDate, venue: dto.venueName ?? dto.location, calendar: calendar),
            rankScore: dto.confidenceScore,
            explanations: explanations
        )
    }

    /// Content-based identity for the same event across different screenshots: normalized title, day and venue.
    public static func similarityKey(title: String, start: Date, venue: String?, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: start)
        let normTitle = DateInference.normalizeText(title).split(separator: " ").prefix(4).joined(separator: " ")
        // First venue word only: flyers often shorten "Skybar Penthouse" to "Skybar".
        let normVenue = DateInference.normalizeText(venue ?? "").split(separator: " ").first.map(String.init) ?? ""
        return DateInference.fnv1a64("\(normTitle)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)|\(normVenue)")
    }

    private static func doorsDate(timeInfo: DateInference.TimeInfo, on start: Date, calendar: Calendar) -> Date? {
        guard let hour = timeInfo.doorsHour else { return nil }
        return calendar.date(bySettingHour: hour, minute: timeInfo.doorsMinute ?? 0, second: 0, of: start)
    }

    private static func lineText(_ id: Int, _ evidence: [EvidenceLine]) -> String {
        evidence.first { $0.id == id }?.text ?? ""
    }

    private static func entity(after markers: [String], in evidence: [EvidenceLine]) -> (value: String, reference: EvidenceReference)? {
        for line in evidence {
            let lower = line.text.lowercased()
            for marker in markers {
                guard let range = lower.range(of: marker) else { continue }
                let offset = lower.distance(from: lower.startIndex, to: range.upperBound)
                let value = String(line.text.dropFirst(offset))
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
                if value.count >= 2 {
                    return (value, EvidenceReference(lineID: line.id, confidence: line.confidence))
                }
            }
        }
        return nil
    }

    /// Short normalized notes: doors, age limit, dress code, price and accessibility cues found on the flyer.
    static func notesSummary(base: String, evidence: [EvidenceLine]) -> String {
        var parts: [String] = base.isEmpty ? [] : [base]
        let text = evidence.map(\.text).joined(separator: "\n")
        let lower = text.lowercased()
        if let age = lower.range(of: "\\b(21\\+|18\\+|all ages)", options: .regularExpression) {
            parts.append("Ages: \(lower[age].uppercased())")
        }
        if let line = evidence.first(where: { $0.text.lowercased().range(of: "dress code|attire", options: .regularExpression) != nil }) {
            parts.append(line.text.trimmingCharacters(in: .whitespaces))
        }
        if let price = text.range(of: "\\$\\s?\\d+(?:\\.\\d{2})?(?:\\s?[-–]\\s?\\$?\\d+)?", options: .regularExpression) {
            parts.append("Price: \(text[price])")
        } else if lower.range(of: "\\bfree (entry|admission|event)\\b|\\bfree\\b", options: .regularExpression) != nil {
            parts.append("Free admission")
        }
        if let line = evidence.first(where: { $0.text.lowercased().range(of: "wheelchair|accessible|\\basl\\b", options: .regularExpression) != nil }) {
            parts.append(line.text.trimmingCharacters(in: .whitespaces))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Semantic Triggers

    static func semanticTriggers(
        extracted: [ExtractedCandidateData],
        temporal: [TemporalEvidence],
        titleRanking: [(text: String, score: Float)],
        quality: OCRQualityReport,
        calendar: Calendar
    ) -> [String] {
        var triggers: [String] = []
        if extracted.contains(where: \.isAmbiguousDate) { triggers.append("ambiguousDate") }

        let eventDays = Set(temporal.filter { $0.role == .eventDate }.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
        if eventDays.count > 1 && extracted.count < eventDays.count { triggers.append("multipleDates") }

        let unlabeledTimes = temporal.filter { $0.role == .other && $0.hour != nil }
        if unlabeledTimes.count >= 2 { triggers.append("unlabeledTimes") }

        if titleRanking.count >= 2, titleRanking[0].score - titleRanking[1].score < 0.08 { triggers.append("lowTitleMargin") }
        if temporal.contains(where: { $0.role == .rsvpDeadline || $0.role == .ticketSale }) { triggers.append("deadline") }
        if quality.lowConfidenceFraction > 0.25 { triggers.append("noisyText") }
        if extracted.contains(where: { $0.titleConfidence < 0.65 }) { triggers.append("weakTitle") }
        return triggers
    }
}
