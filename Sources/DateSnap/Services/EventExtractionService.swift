import Foundation
import NaturalLanguage

// MARK: - Extracted Candidate Data DTO (Sendable Value Type)

public struct ExtractedCandidateData: Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date?
    public var isAllDay: Bool
    public var location: String?
    public var venueName: String?
    public var rsvpUrl: String?
    public var confidenceScore: Float
    public var yearAssumed: Bool
    public var rawTextSnippet: String

    // Additive metadata
    public var dateConfidence: Float
    public var titleConfidence: Float
    public var confidenceTierRaw: String
    public var isAmbiguousDate: Bool
    public var ambiguousFragment: String?
    public var timeZoneIdentifier: String?
    public var dedupeKey: String
    public var phoneNumber: String?
    public var email: String?
    public var notes: String

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

    public func toModel() -> EventCandidate {
        EventCandidate(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            venueName: venueName,
            rsvpUrl: rsvpUrl,
            confidenceScore: confidenceScore,
            yearAssumed: yearAssumed,
            rawTextSnippet: rawTextSnippet,
            dateConfidence: dateConfidence,
            titleConfidence: titleConfidence,
            confidenceTierRaw: confidenceTierRaw,
            isAmbiguousDate: isAmbiguousDate,
            ambiguousFragment: ambiguousFragment,
            timeZoneIdentifier: timeZoneIdentifier,
            dedupeKey: dedupeKey,
            phoneNumber: phoneNumber,
            email: email,
            notes: notes
        )
    }
}

// MARK: - Event Extraction Service Protocol

public protocol EventExtractionServiceProtocol: Sendable {
    /// Baseline extraction from raw text.
    func extractCandidates(from text: String, locale: Locale) async -> [EventCandidate]

    /// Structured extraction with visual layout and bounding box metadata.
    func extractCandidates(from result: OCRResult, locale: Locale) async -> [EventCandidate]
}

extension EventExtractionServiceProtocol {
    public func extractCandidates(from text: String, locale: Locale = .current) async -> [EventCandidate] {
        await extractCandidates(from: text, locale: locale)
    }

    public func extractCandidates(from result: OCRResult, locale: Locale = .current) async -> [EventCandidate] {
        await extractCandidates(from: result, locale: locale)
    }
}

// MARK: - Production Event Extraction Service

public final class EventExtractionService: EventExtractionServiceProtocol {
    public init() {}

    public func extractCandidates(from text: String, locale: Locale = .current) async -> [EventCandidate] {
        let dummyLines = text.components(separatedBy: "\n").enumerated().map { index, line in
            OCRLine(
                text: line,
                confidence: 0.95,
                boundingBox: CGRect(x: 0, y: max(0, 1.0 - (Double(index) * 0.05)), width: 1.0, height: 0.04)
            )
        }
        let result = OCRResult(fullText: text, lines: dummyLines, meanConfidence: 0.95)
        return await extractCandidates(from: result, locale: locale, anchor: Date())
    }

    public func extractCandidates(from result: OCRResult, locale: Locale = .current) async -> [EventCandidate] {
        await extractCandidates(from: result, locale: locale, anchor: Date())
    }

    /// Internal deterministic entry point with explicit anchor date injection.
    public func extractCandidates(
        from result: OCRResult,
        locale: Locale = .current,
        anchor: Date = Date(),
        assetIdentifier: String = "local_asset"
    ) async -> [EventCandidate] {
        let trimmed = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Offload algorithmic parsing to background detached task
        let dtos: [ExtractedCandidateData] = await Task.detached(priority: .userInitiated) {
            EventExtractionCore.extract(from: result, locale: locale, anchor: anchor, assetIdentifier: assetIdentifier)
        }.value

        // Instantiate SwiftData PersistentModel instances on caller's actor context
        return dtos.map { $0.toModel() }
    }
}

// MARK: - Deterministic Extraction Core

/// Pure, synchronous deterministic extraction from OCR, a locale and an injected reference date.
/// Shared by `EventExtractionService` and the `EventUnderstandingPipeline`.
public enum EventExtractionCore {
    public static func extract(
        from result: OCRResult,
        locale: Locale,
        anchor: Date,
        assetIdentifier: String = "local_asset"
    ) -> [ExtractedCandidateData] {
        let trimmed = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Step 1: False-positive rejection
        if DateInference.isFalsePositive(text: trimmed, anchor: anchor) {
            return []
        }

        // Step 2: Line segmentation into blocks, then per-block inference
        return DateInference.segmentIntoEventBlocks(result: result).flatMap { block in
            DateInference.inferCandidates(from: block, locale: locale, anchor: anchor, assetIdentifier: assetIdentifier)
        }
    }
}

// MARK: - DateInference Engine Namespace

public enum DateInference {

    // MARK: - FNV-1a 64-bit Hash & Dedupe Key Generation

    public static func fnv1a64(_ string: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(format: "%016llx", hash)
    }

    public static func normalizeText(_ text: String) -> String {
        var s = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let punctuation = CharacterSet.punctuationCharacters
        s = s.components(separatedBy: punctuation).joined(separator: " ")
        let stopWords: Set<String> = ["the", "a", "an", "presents", "presented", "by"]
        let words = s.split(separator: " ").map(String.init).filter { !stopWords.contains($0) }
        return words.joined(separator: " ")
    }

    public static func computeDedupeKey(
        title: String,
        startDate: Date,
        venueOrLocation: String?,
        assetIdentifier: String
    ) -> String {
        let normTitle = normalizeText(title)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        let roundedTimeStr = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)T\(comps.hour ?? 0):\(comps.minute ?? 0)"
        let normLoc = normalizeText(venueOrLocation ?? "")
        let rawKey = "\(normTitle)|\(roundedTimeStr)|\(normLoc)|\(assetIdentifier)"
        return fnv1a64(rawKey)
    }

    // MARK: - False Positive Filtering (B10)

    public static func isFalsePositive(text: String, anchor: Date) -> Bool {
        let lower = text.lowercased()

        // 1. Receipts & Invoices
        let receiptKeywords = ["subtotal", "total amount", "tax:", "sales tax", "tip:", "amount due", "change due", "cashier", "receipt #", "merchant id"]
        let receiptMatchCount = receiptKeywords.filter { lower.contains($0) }.count
        let priceRegex = try? NSRegularExpression(pattern: "\\$\\d+\\.\\d{2}")
        let priceMatchCount = priceRegex?.numberOfMatches(in: text, range: NSRange(location: 0, length: text.utf16.count)) ?? 0
        if receiptMatchCount >= 2 || (receiptMatchCount >= 1 && priceMatchCount >= 2) || priceMatchCount >= 4 {
            return true
        }

        // 2. Order & Shipping Notifications
        let shippingKeywords = ["order #", "tracking #", "delivered to", "out for delivery", "shipped via", "usps tracking", "fedex tracking", "ups tracking", "return label"]
        if shippingKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        // 3. Pure timestamp screenshots (e.g. clock app or lock screen with only "10:30:15")
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if lines.count == 1 {
            let singleLine = lines[0]
            let timeOnlyRegex = try? NSRegularExpression(pattern: "^\\d{1,2}:\\d{2}(?::\\d{2})?$")
            if timeOnlyRegex?.firstMatch(in: singleLine, range: NSRange(location: 0, length: singleLine.utf16.count)) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Block Segmentation (B5)

    public struct EventBlock: Sendable {
        public var lines: [OCRLine]
        public var fullText: String { lines.map { $0.text }.joined(separator: "\n") }
    }

    public static func segmentIntoEventBlocks(result: OCRResult) -> [EventBlock] {
        guard !result.lines.isEmpty else { return [] }

        var blocks: [EventBlock] = []
        var currentLines: [OCRLine] = []

        for line in result.lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !currentLines.isEmpty {
                    blocks.append(EventBlock(lines: currentLines))
                    currentLines = []
                }
            } else {
                currentLines.append(line)
            }
        }

        if !currentLines.isEmpty {
            blocks.append(EventBlock(lines: currentLines))
        }

        return blocks.isEmpty ? [EventBlock(lines: result.lines)] : blocks
    }

    // MARK: - Core Candidate Inference per Block

    public static func inferCandidates(
        from block: EventBlock,
        locale: Locale,
        anchor: Date,
        assetIdentifier: String
    ) -> [ExtractedCandidateData] {
        let blockText = block.fullText
        let calendar = Calendar.current

        // B1 & B2 & B3: Detect candidate dates, ignoring RSVP-deadline and on-sale lines when another date exists
        let eventDateText = textExcludingDeadlineLines(blockText, locale: locale, anchor: anchor)
        let dateResults = detectDates(in: eventDateText, locale: locale, anchor: anchor)
        guard !dateResults.isEmpty else { return [] }

        // B8: Infer Title from visual hierarchy
        let titleInference = inferTitleFromHierarchy(lines: block.lines, fullText: blockText)
        let title = titleInference.title
        let titleScore = titleInference.confidence

        // Location, Venue, and Contacts
        let (venue, location) = extractLocationAndVenue(lines: block.lines, fullText: blockText, excludingTitle: title)
        let rsvpUrl = extractRSVPOrURL(from: blockText)
        let phone = extractPhoneNumber(from: blockText)
        let email = extractEmail(from: blockText)

        // B7: Timezone Extraction
        let timeZoneId = extractTimezone(from: blockText)

        // B6: Doors time is not the start when a show time exists; keep it for the event notes.
        let notes = doorsNote(in: blockText) ?? ""

        var candidates: [ExtractedCandidateData] = []

        for dateItem in dateResults {
            // Date boundary checks (not > 24 months past or > 5 years future)
            let monthInterval = calendar.dateComponents([.month], from: anchor, to: dateItem.startDate).month ?? 0
            if monthInterval < -24 && dateItem.yearAssumed {
                continue
            }
            if monthInterval > 60 {
                continue
            }

            // B9: Multi-dimensional confidence scoring
            var dateConfidence = dateItem.sourceReliability
            if !dateItem.hasExplicitYear {
                dateConfidence *= 0.92
            }
            if dateItem.isAmbiguous {
                dateConfidence *= 0.70
            }

            var locConfidence: Float = 0.50
            if location != nil || venue != nil { locConfidence = 0.90 }
            if rsvpUrl != nil { locConfidence = min(1.0, locConfidence + 0.05) }

            // Geometric mean: pow(date, 0.55) * pow(title, 0.30) * pow(location, 0.15)
            let rawOverall = pow(Double(dateConfidence), 0.55) * pow(Double(titleScore), 0.30) * pow(Double(locConfidence), 0.15)
            let clampedOverall = Float(max(0.40, min(0.99, rawOverall)))
            let tier = ConfidenceTier.from(score: clampedOverall)

            // B11: Dedupe Key
            let dedupeKey = computeDedupeKey(
                title: title,
                startDate: dateItem.startDate,
                venueOrLocation: venue ?? location,
                assetIdentifier: assetIdentifier
            )

            let candidate = ExtractedCandidateData(
                id: UUID().uuidString,
                title: title,
                startDate: dateItem.startDate,
                endDate: dateItem.endDate,
                isAllDay: dateItem.isAllDay,
                location: location,
                venueName: venue,
                rsvpUrl: rsvpUrl,
                confidenceScore: clampedOverall,
                yearAssumed: dateItem.yearAssumed,
                rawTextSnippet: blockText,
                dateConfidence: dateConfidence,
                titleConfidence: titleScore,
                confidenceTierRaw: tier.rawValue,
                isAmbiguousDate: dateItem.isAmbiguous,
                ambiguousFragment: dateItem.ambiguousFragment,
                timeZoneIdentifier: timeZoneId,
                dedupeKey: dedupeKey,
                phoneNumber: phone,
                email: email,
                notes: notes
            )

            candidates.append(candidate)
        }

        return candidates
    }

    // MARK: - B1, B2, B3, B4, B6: Date Detection & Inference Cascade

    public struct DetectedDateItem: Sendable {
        public var startDate: Date
        public var endDate: Date?
        public var isAllDay: Bool
        public var yearAssumed: Bool
        public var hasExplicitYear: Bool
        public var isAmbiguous: Bool
        public var ambiguousFragment: String?
        public var sourceReliability: Float
    }

    public static func detectDates(in text: String, locale: Locale, anchor: Date) -> [DetectedDateItem] {
        let calendar = Calendar.current
        var items: [DetectedDateItem] = []

        // B6: Parse times and windows across the text
        let timeInfo = parseTimesAndWindows(in: text)

        // 1. Relative-phrase Lexicon Detector (B3)
        if let relativeMatch = resolveRelativePhrases(in: text, anchor: anchor, calendar: calendar) {
            let start = relativeMatch.date
            var end: Date? = nil
            let isAllDay = !relativeMatch.hasExplicitTime && !timeInfo.hasTime

            if timeInfo.hasTime {
                var comps = calendar.dateComponents([.year, .month, .day], from: start)
                comps.hour = timeInfo.startHour
                comps.minute = timeInfo.startMinute
                let combinedStart = calendar.date(from: comps) ?? start

                if let endH = timeInfo.endHour {
                    var endComps = calendar.dateComponents([.year, .month, .day], from: start)
                    if endH < (timeInfo.startHour ?? 0) {
                        endComps.day = (endComps.day ?? 1) + 1
                    }
                    endComps.hour = endH
                    endComps.minute = timeInfo.endMinute ?? 0
                    end = calendar.date(from: endComps)
                } else {
                    end = EventDurationPolicy.fallbackEnd(for: combinedStart)
                }

                items.append(DetectedDateItem(
                    startDate: combinedStart,
                    endDate: end,
                    isAllDay: false,
                    yearAssumed: true,
                    hasExplicitYear: false,
                    isAmbiguous: false,
                    ambiguousFragment: nil,
                    sourceReliability: 0.92
                ))
                return items
            } else {
                items.append(DetectedDateItem(
                    startDate: start,
                    endDate: end,
                    isAllDay: isAllDay,
                    yearAssumed: true,
                    hasExplicitYear: false,
                    isAmbiguous: false,
                    ambiguousFragment: nil,
                    sourceReliability: 0.92
                ))
                return items
            }
        }

        // 2. Month-Name Range & Single Date Detector (B1, B5)
        let monthRanges = detectMonthDates(in: text, anchor: anchor, calendar: calendar, timeInfo: timeInfo)
        if !monthRanges.isEmpty {
            return monthRanges
        }

        // 3. Numeric Date Detector with Locale Disambiguation (B2)
        if let numericMatch = detectNumericDate(in: text, locale: locale, anchor: anchor, calendar: calendar, timeInfo: timeInfo) {
            return [numericMatch]
        }

        // 4. Fallback: NSDataDetector baseline
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            if let first = matches.first, let d = first.date {
                var endDate: Date? = nil
                if first.duration > 0 {
                    endDate = d.addingTimeInterval(first.duration)
                } else if timeInfo.hasTime, let endH = timeInfo.endHour {
                    var endComps = calendar.dateComponents([.year, .month, .day], from: d)
                    endComps.hour = endH
                    endComps.minute = timeInfo.endMinute ?? 0
                    endDate = calendar.date(from: endComps)
                }

                let hasExplicitYear = findExplicitYear(in: text, anchor: anchor, calendar: calendar) != nil

                var effectiveStart = d
                var yearAssumed = false
                if !hasExplicitYear {
                    yearAssumed = true
                    if effectiveStart < anchor {
                        effectiveStart = calendar.date(byAdding: .year, value: 1, to: effectiveStart) ?? effectiveStart
                        if let e = endDate {
                            endDate = calendar.date(byAdding: .year, value: 1, to: e)
                        }
                    }
                }

                items.append(DetectedDateItem(
                    startDate: effectiveStart,
                    endDate: endDate,
                    isAllDay: !timeInfo.hasTime,
                    yearAssumed: yearAssumed,
                    hasExplicitYear: hasExplicitYear,
                    isAmbiguous: false,
                    ambiguousFragment: nil,
                    sourceReliability: 0.95
                ))
            }
        }

        return items
    }

    // MARK: - B3. Relative Date Resolution

    public struct RelativeResult: Sendable {
        public var date: Date
        public var hasExplicitTime: Bool
    }

    public static func resolveRelativePhrases(in text: String, anchor: Date, calendar: Calendar) -> RelativeResult? {
        let lower = text.lowercased()

        // Today / Tonight
        if lower.contains("tonight") {
            var comps = calendar.dateComponents([.year, .month, .day], from: anchor)
            comps.hour = 19
            comps.minute = 0
            let d = calendar.date(from: comps) ?? anchor
            return RelativeResult(date: d, hasExplicitTime: true)
        }
        if lower.contains("today") {
            return RelativeResult(date: anchor, hasExplicitTime: false)
        }

        // Tomorrow / Tmrw
        if lower.contains("tomorrow") || lower.contains("tmrw") {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: anchor) ?? anchor
            return RelativeResult(date: nextDay, hasExplicitTime: false)
        }

        // in N days
        let inDaysRegex = try? NSRegularExpression(pattern: "\\bin\\s+(\\d+)\\s+days?\\b")
        if let match = inDaysRegex?.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)),
           let r = Range(match.range(at: 1), in: lower),
           let n = Int(lower[r]) {
            let target = calendar.date(byAdding: .day, value: n, to: anchor) ?? anchor
            return RelativeResult(date: target, hasExplicitTime: false)
        }

        // in N weeks
        let inWeeksRegex = try? NSRegularExpression(pattern: "\\bin\\s+(\\d+)\\s+weeks?\\b")
        if let match = inWeeksRegex?.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)),
           let r = Range(match.range(at: 1), in: lower),
           let n = Int(lower[r]) {
            let target = calendar.date(byAdding: .weekOfYear, value: n, to: anchor) ?? anchor
            return RelativeResult(date: target, hasExplicitTime: false)
        }

        // "this/coming <weekday>" vs "next <weekday>"
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
            "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7
        ]

        let weekdayPattern = "(?:this|coming|next)\\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)"
        let regex = try? NSRegularExpression(pattern: weekdayPattern)
        if let match = regex?.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) {
            let fullMatched = (lower as NSString).substring(with: match.range)
            let nameMatched = (lower as NSString).substring(with: match.range(at: 1))

            if let targetWeekday = weekdays[nameMatched] {
                let anchorWeekday = calendar.component(.weekday, from: anchor)
                var daysAhead = (targetWeekday - anchorWeekday + 7) % 7
                if daysAhead == 0 { daysAhead = 7 }

                /// Convention: "next <weekday>" strictly means the following week (daysAhead + 7).
                if fullMatched.hasPrefix("next") {
                    daysAhead += 7
                }

                let d = calendar.date(byAdding: .day, value: daysAhead, to: anchor) ?? anchor
                return RelativeResult(date: d, hasExplicitTime: false)
            }
        }

        return nil
    }

    // MARK: - Month Dates & Date Range Expansion (B1, B4, B5)

    public static func detectMonthDates(
        in text: String,
        anchor: Date,
        calendar: Calendar,
        timeInfo: TimeInfo
    ) -> [DetectedDateItem] {
        let monthsPattern = "(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)"
        let weekdayPrefix = "(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)[,\\s]+)?"

        // Pattern 1: Month Name followed by range or single day (e.g. "Oct 12-14", "Oct 12–14, 2026", "July 18")
        let pattern = "(?i)\(weekdayPrefix)(\(monthsPattern))\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:\\s*[-–—to]+\\s*(\\d{1,2})(?:st|nd|rd|th)?)?(?:,?\\s*(\\d{4}))?"
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)) ?? []

        var results: [DetectedDateItem] = []

        for match in matches {
            guard match.numberOfRanges > 2,
                  let monthRange = Range(match.range(at: 1), in: text),
                  let startDayRange = Range(match.range(at: 2), in: text) else { continue }

            let monthStr = String(text[monthRange]).lowercased()
            guard let monthNum = monthNumber(from: monthStr),
                  let startDay = Int(text[startDayRange]) else { continue }

            var endDay: Int? = nil
            if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound,
               let rangeEnd = Range(match.range(at: 3), in: text) {
                endDay = Int(text[rangeEnd])
            }

            var explicitYear: Int? = nil
            if match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound,
               let yearRange = Range(match.range(at: 4), in: text) {
                explicitYear = Int(text[yearRange])
            }

            // B4: Assumed Year inference
            let (resolvedDate, yearAssumed) = resolveAssumedYear(
                month: monthNum,
                day: startDay,
                hour: timeInfo.startHour,
                minute: timeInfo.startMinute,
                explicitYear: explicitYear,
                text: text,
                anchor: anchor,
                calendar: calendar
            )

            // B5: If day range detected (e.g. Oct 12-14), expand to one candidate per day (≤ 14 days)
            if let endD = endDay, endD > startDay && (endD - startDay) <= 14 {
                for offset in 0...(endD - startDay) {
                    if let expandedDate = calendar.date(byAdding: .day, value: offset, to: resolvedDate) {
                        var dayEndDate: Date? = nil
                        if timeInfo.hasTime, let endH = timeInfo.endHour {
                            var endComps = calendar.dateComponents([.year, .month, .day], from: expandedDate)
                            endComps.hour = endH
                            endComps.minute = timeInfo.endMinute ?? 0
                            dayEndDate = calendar.date(from: endComps)
                        } else if timeInfo.hasTime {
                            dayEndDate = EventDurationPolicy.fallbackEnd(for: expandedDate)
                        }

                        results.append(DetectedDateItem(
                            startDate: expandedDate,
                            endDate: dayEndDate,
                            isAllDay: !timeInfo.hasTime,
                            yearAssumed: yearAssumed,
                            hasExplicitYear: explicitYear != nil,
                            isAmbiguous: false,
                            ambiguousFragment: nil,
                            sourceReliability: 0.90
                        ))
                    }
                }
            } else {
                var singleEndDate: Date? = nil
                if timeInfo.hasTime, let endH = timeInfo.endHour {
                    var endComps = calendar.dateComponents([.year, .month, .day], from: resolvedDate)
                    if endH < (timeInfo.startHour ?? 0) {
                        endComps.day = (endComps.day ?? 1) + 1
                    }
                    endComps.hour = endH
                    endComps.minute = timeInfo.endMinute ?? 0
                    singleEndDate = calendar.date(from: endComps)
                } else if timeInfo.hasTime {
                    singleEndDate = EventDurationPolicy.fallbackEnd(for: resolvedDate)
                }

                results.append(DetectedDateItem(
                    startDate: resolvedDate,
                    endDate: singleEndDate,
                    isAllDay: !timeInfo.hasTime,
                    yearAssumed: yearAssumed,
                    hasExplicitYear: explicitYear != nil,
                    isAmbiguous: false,
                    ambiguousFragment: nil,
                    sourceReliability: 0.90
                ))
            }
        }

        return results
    }

    // MARK: - B2. Numeric Date Detection with Locale Disambiguation

    public static func detectNumericDate(
        in text: String,
        locale: Locale,
        anchor: Date,
        calendar: Calendar,
        timeInfo: TimeInfo
    ) -> DetectedDateItem? {
        let numericRegex = try? NSRegularExpression(pattern: "\\b(\\d{1,2})[/.-](\\d{1,2})(?:[/.-](\\d{2,4}))?\\b")
        let matches = numericRegex?.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)) ?? []

        for match in matches {
            guard let r1 = Range(match.range(at: 1), in: text),
                  let r2 = Range(match.range(at: 2), in: text),
                  let num1 = Int(text[r1]),
                  let num2 = Int(text[r2]) else { continue }

            var explicitYear: Int? = nil
            if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound,
               let yRange = Range(match.range(at: 3), in: text),
               var y = Int(text[yRange]) {
                if y < 100 { y += 2000 }
                explicitYear = y
            }

            var month: Int
            var day: Int
            var isAmbiguous = false
            var ambiguousFragment: String? = nil

            if num1 > 12 {
                day = num1
                month = num2
            } else if num2 > 12 {
                month = num1
                day = num2
            } else {
                // Both numbers <= 12
                let region = locale.region?.identifier ?? ""
                let isUS = locale.identifier.hasPrefix("en_US") || region == "US"
                let isKnownDMY = ["GB", "UK", "DE", "FR", "ES", "IT", "AU", "NZ"].contains(region) ||
                    ["en_GB", "de_DE", "fr_FR", "es_ES"].contains(where: { locale.identifier.hasPrefix($0) })

                if isUS {
                    month = num1
                    day = num2
                } else if isKnownDMY {
                    day = num1
                    month = num2
                } else {
                    // Ambiguous locale (e.g. en_001) -> Prompt, don't guess
                    isAmbiguous = true
                    ambiguousFragment = "\(num1)/\(num2)"
                    month = num1
                    day = num2
                }
            }

            guard month >= 1 && month <= 12 && day >= 1 && day <= 31 else { continue }

            let (resolvedDate, yearAssumed) = resolveAssumedYear(
                month: month,
                day: day,
                hour: timeInfo.startHour,
                minute: timeInfo.startMinute,
                explicitYear: explicitYear,
                text: text,
                anchor: anchor,
                calendar: calendar
            )

            var endDate: Date? = nil
            if timeInfo.hasTime, let endH = timeInfo.endHour {
                var endComps = calendar.dateComponents([.year, .month, .day], from: resolvedDate)
                if endH < (timeInfo.startHour ?? 0) {
                    endComps.day = (endComps.day ?? 1) + 1
                }
                endComps.hour = endH
                endComps.minute = timeInfo.endMinute ?? 0
                endDate = calendar.date(from: endComps)
            } else if timeInfo.hasTime {
                endDate = EventDurationPolicy.fallbackEnd(for: resolvedDate)
            }

            return DetectedDateItem(
                startDate: resolvedDate,
                endDate: endDate,
                isAllDay: !timeInfo.hasTime,
                yearAssumed: yearAssumed,
                hasExplicitYear: explicitYear != nil,
                isAmbiguous: isAmbiguous,
                ambiguousFragment: ambiguousFragment,
                sourceReliability: isAmbiguous ? 0.50 : 0.80
            )
        }

        return nil
    }

    // MARK: - B4. Assumed Year Chronological & Leap-Year Resolution

    public static func resolveAssumedYear(
        month: Int,
        day: Int,
        hour: Int?,
        minute: Int?,
        explicitYear: Int?,
        text: String,
        anchor: Date,
        calendar: Calendar
    ) -> (date: Date, yearAssumed: Bool) {
        let anchorYear = calendar.component(.year, from: anchor)
        let effectiveYear: Int
        var yearAssumed = false

        if let y = explicitYear {
            effectiveYear = y
        } else {
            // Check if a plausible 4-digit year exists anywhere in the text
            if let y = findExplicitYear(in: text, anchor: anchor, calendar: calendar) {
                effectiveYear = y
            } else {
                yearAssumed = true
                var targetYear = anchorYear

                // Validate Feb 29 for leap years
                if month == 2 && day == 29 {
                    targetYear = findNextLeapYear(from: anchorYear)
                }

                var testComps = DateComponents()
                testComps.year = targetYear
                testComps.month = month
                testComps.day = (month == 2 && day == 29 && !isLeapYear(targetYear)) ? 28 : day
                testComps.hour = hour ?? 12
                testComps.minute = minute ?? 0

                let testDate = calendar.date(from: testComps) ?? anchor
                if testDate < anchor {
                    targetYear += 1
                    if month == 2 && day == 29 && !isLeapYear(targetYear) {
                        targetYear = findNextLeapYear(from: targetYear)
                    }
                }
                effectiveYear = targetYear
            }
        }

        var comps = DateComponents()
        comps.year = effectiveYear
        comps.month = month
        comps.day = (month == 2 && day == 29 && !isLeapYear(effectiveYear)) ? 28 : day
        comps.hour = hour ?? 0
        comps.minute = minute ?? 0

        let resultDate = calendar.date(from: comps) ?? anchor
        return (resultDate, yearAssumed)
    }

    /// First four-digit year in `text` that is plausible for an event relative to `anchor`
    /// (from 2 years before to 10 years after), replacing a fixed calendar window.
    public static func findExplicitYear(in text: String, anchor: Date, calendar: Calendar = .current) -> Int? {
        let anchorYear = calendar.component(.year, from: anchor)
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\d/.:-])((?:19|20|21)\\d{2})(?![\\d:])") else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        for match in regex.matches(in: text, range: range) {
            guard let r = Range(match.range(at: 1), in: text), let year = Int(text[r]) else { continue }
            if (anchorYear - 2)...(anchorYear + 10) ~= year {
                return year
            }
        }
        return nil
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }

    private static func findNextLeapYear(from year: Int) -> Int {
        var y = year
        while !isLeapYear(y) {
            y += 1
        }
        return y
    }

    // MARK: - B6. Time Parsing, Windows & Multi-Marker Disambiguation

    /// Lines whose dates are deadlines or sale dates rather than the event's own date.
    public static let deadlineVocabulary = "rsvp by|rsvp before|rsvp no later|register by|registration closes|reply by|sign up by|deadline|on sale|presale|pre-sale|tickets available"

    public static func isDeadlineLine(_ line: String) -> Bool {
        line.lowercased().range(of: deadlineVocabulary, options: .regularExpression) != nil
    }

    /// Block text without deadline/on-sale lines, when the remaining lines still contain a date.
    static func textExcludingDeadlineLines(_ text: String, locale: Locale, anchor: Date) -> String {
        let lines = text.components(separatedBy: "\n")
        let kept = lines.filter { !isDeadlineLine($0) }
        guard kept.count < lines.count else { return text }
        let keptText = kept.joined(separator: "\n")
        return detectDates(in: keptText, locale: locale, anchor: anchor).isEmpty ? text : keptText
    }

    /// Words that mark the main start ("Show 8:30", "8:30 Headliner set").
    public static let showVocabulary = "\\b(show|showtime|headlin\\w*|main set|performance|kick ?off|starts?|begins?)\\b"
    /// Words that mark an earlier arrival time ("Doors 7", "7:00 Lounge opens", "Check-in 6:30").
    public static let doorsVocabulary = "\\b(doors?|opens?|arrival|arrive|check-?in)\\b"

    /// Parsed times for a block. `doors*` is set only when a separate show time became the start.
    public typealias TimeInfo = (hasTime: Bool, startHour: Int?, startMinute: Int?, endHour: Int?, endMinute: Int?, doorsHour: Int?, doorsMinute: Int?)

    public static func parseTimesAndWindows(in text: String) -> TimeInfo {
        let lines = text.components(separatedBy: "\n")

        // The start must not be the tail of a longer number (e.g. the "27" in "04/05/2027 7pm").
        let windowPattern = "(?i)(?<![\\d/.:])(\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?)\\s*(?:[-–—to\\suntil]+\\s*(\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)))"
        let windowRegex = try? NSRegularExpression(pattern: windowPattern)

        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = windowRegex?.firstMatch(in: line, range: range) {
                let startRaw = (line as NSString).substring(with: match.range(at: 1))
                let endRaw = (line as NSString).substring(with: match.range(at: 2))

                if let s = parseSingleTime(startRaw), let e = parseSingleTime(endRaw) {
                    return (true, s.hour, s.minute, e.hour, e.minute, nil, nil)
                }
            }
        }

        // Multi-marker check (e.g. "Doors 7:00 PM", "Show 8:30 PM", "Noon", "Midnight").
        // Group 1 captures the marker so doors and show times can be told apart per match.
        let singlePattern = "(?i)(doors?\\s+open\\s+|doors?\\s+|show(?:time)?\\s+)?(?<![\\d/.:])(\\d{1,2}:\\d{2}\\s*(?:am|pm)?|\\d{1,2}\\s*(?:am|pm)|noon|midnight)"
        let singleRegex = try? NSRegularExpression(pattern: singlePattern)

        enum Marker { case none, doors, show }
        var detectedTimes: [(hour: Int, minute: Int, marker: Marker)] = []

        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            let lowerLine = line.lowercased()
            let matches = singleRegex?.matches(in: line, range: range) ?? []
            for m in matches {
                let raw = (line as NSString).substring(with: m.range(at: 2))
                var marker = Marker.none
                if m.range(at: 1).location != NSNotFound {
                    let prefix = (line as NSString).substring(with: m.range(at: 1)).lowercased()
                    marker = prefix.hasPrefix("door") ? .doors : .show
                } else if lowerLine.range(of: showVocabulary, options: .regularExpression) != nil {
                    marker = .show
                } else if lowerLine.range(of: doorsVocabulary, options: .regularExpression) != nil {
                    marker = .doors
                }
                if let t = parseSingleTime(raw) {
                    detectedTimes.append((t.hour, t.minute, marker))
                }
            }
        }

        guard !detectedTimes.isEmpty else {
            return (false, nil, nil, nil, nil, nil, nil)
        }

        func minutes(_ t: (hour: Int, minute: Int, marker: Marker)) -> Int { t.hour * 60 + t.minute }

        // Doors + Show: the show is the event start; doors are preserved separately for notes.
        if let show = detectedTimes.first(where: { $0.marker == .show }) {
            let doors = detectedTimes.first(where: { $0.marker == .doors })
            let laterEnd = detectedTimes
                .filter { $0.marker == .none && minutes($0) > minutes(show) }
                .max(by: { minutes($0) < minutes($1) })
            return (true, show.hour, show.minute, laterEnd?.hour, laterEnd?.minute, doors?.hour, doors?.minute)
        }

        if detectedTimes.count >= 2 {
            // Earliest as start, latest as end
            let sorted = detectedTimes.sorted { minutes($0) < minutes($1) }
            if let earliest = sorted.first, let latest = sorted.last {
                return (true, earliest.hour, earliest.minute, latest.hour, latest.minute, nil, nil)
            }
        }

        let first = detectedTimes[0]
        return (true, first.hour, first.minute, nil, nil, nil, nil)
    }

    /// Human-readable note for a doors time that was not used as the event start (e.g. "Doors open at 7:00 PM").
    public static func doorsNote(in text: String) -> String? {
        let info = parseTimesAndWindows(in: text)
        guard let hour = info.doorsHour else { return nil }
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = info.doorsMinute ?? 0
        guard let date = Calendar.current.date(from: comps) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return "Doors open at \(formatter.string(from: date))"
    }

    public static func parseSingleTime(_ raw: String) -> (hour: Int, minute: Int)? {
        let clean = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if clean == "noon" || clean == "midday" {
            return (12, 0)
        }
        if clean == "midnight" {
            return (0, 0)
        }

        let isPM = clean.contains("pm")
        let isAM = clean.contains("am")
        let digits = clean.replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "").trimmingCharacters(in: .whitespaces)
        let parts = digits.components(separatedBy: ":")

        guard let h = Int(parts[0]) else { return nil }
        let m = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0

        var hour = h
        if isPM && hour < 12 {
            hour += 12
        } else if isAM && hour == 12 {
            hour = 0
        } else if !isPM && !isAM {
            // Meridiem inference when absent: 1-6 -> PM, 7-11 -> PM, 12 -> PM
            if hour >= 1 && hour <= 11 {
                hour += 12
            }
        }

        guard (0...23).contains(hour), (0...59).contains(m) else { return nil }
        return (hour, m)
    }

    // MARK: - B7. Timezone Extraction

    public static func extractTimezone(from text: String) -> String {
        let tzRegex = try? NSRegularExpression(pattern: "\\b(PST|PDT|EST|EDT|CST|CDT|MST|MDT|GMT|UTC|BST|CET|IST)\\b")
        if let match = tzRegex?.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
           let r = Range(match.range, in: text) {
            let abbr = String(text[r]).uppercased()
            if let tzId = NSTimeZone.abbreviationDictionary[abbr] {
                return tzId
            }
        }
        return Calendar.current.timeZone.identifier
    }

    // MARK: - B8. Visual-Hierarchy Title Inference

    public struct TitleInferenceResult: Sendable {
        public var title: String
        public var confidence: Float
    }

    /// Every plausible title line with its hierarchy score, best first.
    public static func rankTitleCandidates(lines: [OCRLine]) -> [(line: OCRLine, score: Float)] {
        guard !lines.isEmpty else { return [] }

        let boilerplateKeywords = [
            "tickets", "door", "doors", "admission", "free", "rsvp", "presale", "21+", "18+",
            "sound by", "presented by", "music by", "all ages", "instagram", "screenshot",
            "flyer", "live", "am", "pm", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
            "subtotal", "total", "tax", "price"
        ]

        var scoredLines: [(line: OCRLine, score: Float)] = []

        // In Vision coords, origin is lower-left (0,0). Upper 60% of image corresponds to y >= 0.40.
        let upperLines = lines.filter { $0.boundingBox.origin.y >= 0.40 }
        let candidatePool = upperLines.isEmpty ? lines : upperLines

        let maxFontProxy = candidatePool.map { $0.fontSizeProxy }.max() ?? 1.0

        for line in candidatePool {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 3 || trimmed.count > 70 { continue }

            let lower = trimmed.lowercased()
            // Whole-word match so "SUNSET" isn't read as "sun" (Sunday) or "CAMP" as "am".
            let words = Set(lower.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+")).inverted).filter { !$0.isEmpty })
            let containsBoilerplate = boilerplateKeywords.contains { keyword in
                keyword.contains(" ") ? lower.contains(keyword) : words.contains(keyword)
            }
            let isNumericDate = trimmed.range(of: "^\\d{1,2}[/.-]\\d{1,2}", options: .regularExpression) != nil
            if isNumericDate || isTemporalOnlyLine(trimmed) { continue }

            let widthScore = Float(line.normalizedWidth) * 0.45
            let fontRank = Float(line.fontSizeProxy / max(0.001, maxFontProxy)) * 0.30
            // Top quartile bonus: maxY in top 25% of image (y >= 0.75)
            let topQuartileBonus: Float = line.boundingBox.maxY >= 0.75 ? 0.15 : 0.0
            let penalty: Float = containsBoilerplate ? 0.25 : 0.0

            let totalScore = max(0.1, widthScore + fontRank + topQuartileBonus - penalty)
            scoredLines.append((line, totalScore))
        }

        return scoredLines.sorted(by: { $0.score > $1.score })
    }

    public static func inferTitleFromHierarchy(lines: [OCRLine], fullText: String) -> TitleInferenceResult {
        guard !lines.isEmpty else {
            return TitleInferenceResult(title: "Upcoming Event", confidence: 0.50)
        }

        let scoredLines = rankTitleCandidates(lines: lines)
        if let best = scoredLines.sorted(by: { $0.score > $1.score }).first {
            let titleConf = min(0.98, max(0.60, best.score))
            return TitleInferenceResult(title: best.line.text, confidence: titleConf)
        }

        // Fallback: heuristic prefix search
        for line in lines.prefix(3) {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 3 && trimmed.count < 50 && !trimmed.contains(":") {
                return TitleInferenceResult(title: trimmed, confidence: 0.75)
            }
        }

        return TitleInferenceResult(title: lines.first?.text ?? "Upcoming Event", confidence: 0.65)
    }

    // MARK: - Location, Venue, and Contact Field Extraction

    /// True when a line is just a date/time ("9am - 1pm", "Saturday, October 31") with no other words.
    public static func isTemporalOnlyLine(_ text: String) -> Bool {
        let temporalWords: Set<String> = [
            "am", "pm", "noon", "midnight", "at", "to", "from", "until", "till", "and", "the", "of", "on",
            "jan", "january", "feb", "february", "mar", "march", "apr", "april", "may", "jun", "june", "jul", "july",
            "aug", "august", "sep", "sept", "september", "oct", "october", "nov", "november", "dec", "december",
            "mon", "monday", "tue", "tues", "tuesday", "wed", "wednesday", "thu", "thur", "thurs", "thursday",
            "fri", "friday", "sat", "saturday", "sun", "sunday", "today", "tonight", "tomorrow", "st", "nd", "rd", "th"
        ]
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        let hasDigits = text.rangeOfCharacter(from: .decimalDigits) != nil
        let otherWords = words.filter { !temporalWords.contains($0) }
        return otherWords.isEmpty && (hasDigits || !words.isEmpty)
    }

    /// True when a line contains a clock time or a date, even alongside other words.
    static func containsTimeOrDate(_ text: String) -> Bool {
        text.range(of: "(?i)(?<![\\d/.:])(\\d{1,2}:\\d{2}|\\d{1,2}\\s*(am|pm))|\\b\\d{1,2}[/.-]\\d{1,2}\\b", options: .regularExpression) != nil
    }

    public static func extractLocationAndVenue(lines: [OCRLine], fullText: String) -> (venue: String?, address: String?) {
        extractLocationAndVenue(lines: lines, fullText: fullText, excludingTitle: nil)
    }

    public static func extractLocationAndVenue(lines: [OCRLine], fullText: String, excludingTitle title: String?) -> (venue: String?, address: String?) {
        let addressPattern = "\\b\\d{1,5}\\s+[A-Za-z0-9#\\.\\s]+(?:Street|St|Avenue|Ave|Boulevard|Blvd|Road|Rd|Drive|Dr|Way|Lane|Ln|Court|Ct|Plaza|Plz|Suite|Ste|Floor)\\b"
        let addressRegex = try? NSRegularExpression(pattern: addressPattern, options: [.caseInsensitive])

        var address: String?
        var venue: String?

        let rawLines = lines.map { $0.text.trimmingCharacters(in: .whitespaces) }

        for (index, line) in rawLines.enumerated() {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = addressRegex?.firstMatch(in: line, range: range) {
                // Keep the rest of a short address line (city, state) rather than just the street.
                let street = (line as NSString).substring(with: match.range)
                let fromStreet = (line as NSString).substring(from: match.range.location).trimmingCharacters(in: .whitespaces)
                address = fromStreet.count <= 80 ? fromStreet : street
                if index > 0 {
                    let prev = rawLines[index - 1]
                    if prev.count > 3 && prev.count < 40 && !prev.contains(":") {
                        venue = prev
                    }
                }
                break
            }

            // Venue keywords, ignoring the title line and lines that carry a time or date
            // ("7:00 PM Lounge Opens" is a doors time, "Book Club" the event itself).
            let venueKeywords = ["skybar", "penthouse", "lounge", "rooftop", "theatre", "theater", "stadium", "hall", "plaza",
                                 "center", "centre", "club", "arena", "park", "square", "library", "studio", "museum", "gallery",
                                 "church", "cafe", "café", "bar", "pub", "hotel", "ballroom", "room", "venue", "garden", "gardens"]
            let isTitle = title.map { $0.caseInsensitiveCompare(line) == .orderedSame } ?? false
            let lowerWords = Set(line.lowercased().components(separatedBy: CharacterSet.letters.inverted))
            if !isTitle && !containsTimeOrDate(line) && venueKeywords.contains(where: { lowerWords.contains($0) || ($0.count > 5 && line.lowercased().contains($0)) }) {
                if venue == nil && line.count < 50 {
                    venue = line
                }
            }
        }

        return (venue, address)
    }

    public static func extractRSVPOrURL(from text: String) -> String? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            if let first = matches.first, let url = first.url {
                return url.absoluteString
            }
        }
        let ticketRegex = try? NSRegularExpression(pattern: "(?i)(?:rsvp|tickets|info):?\\s*([A-Za-z0-9_\\-\\./]+)")
        if let match = ticketRegex?.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
            return (text as NSString).substring(with: match.range(at: 1))
        }
        return nil
    }

    public static func extractPhoneNumber(from text: String) -> String? {
        let phoneRegex = try? NSRegularExpression(pattern: "\\b(?:\\+?1[-.\\s]?)?\\(?([2-9]\\d{2})\\)?[-.\\s]?(\\d{3})[-.\\s]?(\\d{4})\\b")
        if let match = phoneRegex?.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
            return (text as NSString).substring(with: match.range)
        }
        return nil
    }

    public static func extractEmail(from text: String) -> String? {
        let emailRegex = try? NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        if let match = emailRegex?.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
            return (text as NSString).substring(with: match.range)
        }
        return nil
    }

    private static func monthNumber(from string: String) -> Int? {
        let months = [
            "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3,
            "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
            "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9, "oct": 10,
            "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12
        ]
        for (key, val) in months {
            if string.lowercased().contains(key) {
                return val
            }
        }
        return nil
    }
}
