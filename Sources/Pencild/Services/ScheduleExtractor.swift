import Foundation

/// Work schedules and multi-date flyers: splits a screenshot's lines into dated entries, each with
/// its own times and label, and produces one event per entry. It only takes over when a screenshot
/// has two or more dated entries; a single flyer keeps the regular extraction path.
enum ScheduleExtractor {
    struct Clock: Equatable {
        var hour: Int
        var minute: Int
    }

    struct Entry: Equatable {
        var date: Date
        var hasExplicitYear: Bool
        var resolvedFromWeekday: Bool
        var start: Clock?
        var end: Clock?
        var label: String?
        var source: String
    }

    // MARK: - Patterns

    private static let month = "(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|June?|July?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"
    private static let monthDay = try! NSRegularExpression(
        pattern: "(?i)\\b\(month)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b(?![:.]\\d)(\\s*[-–—]\\s*\\d{1,2}\\b(?![:.]\\d))?(?:,?\\s+(\\d{4}))?"
    )
    private static let dayMonth = try! NSRegularExpression(
        pattern: "(?i)\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+\(month)\\b\\.?(?:,?\\s+(\\d{4}))?"
    )
    private static let numeric = try! NSRegularExpression(pattern: "(?<![\\d/])(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?(?![\\d/])")
    private static let leadingWeekday = try! NSRegularExpression(
        pattern: "(?i)^\\s*(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:day)?s?\\b"
    )
    private static let weekdayWords = try! NSRegularExpression(
        pattern: "(?i)\\b(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:day)?s?\\b\\.?"
    )
    private static let weekOf = try! NSRegularExpression(pattern: "(?i)\\bweek\\s+(?:of|starting|beginning|commencing)\\b")
    private static let timeRange = try! NSRegularExpression(
        pattern: "(?i)(?<![\\d:])(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm|a|p)?\\.?\\s*(?:-|–|—|to|until)\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm|a|p)?\\b"
    )
    private static let singleTime = try! NSRegularExpression(
        pattern: "(?i)(?<![\\d:])(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm|a\\.m\\.|p\\.m\\.)(?![a-z])|\\b(noon)\\b"
    )
    private static let dayOff = try! NSRegularExpression(
        pattern: "(?i)^\\W*(?:off|day off|time off|rest day|not scheduled|unavailable|no shift)\\W*$"
    )

    /// Words that mark a screenshot as a work schedule rather than a list of events.
    private static let workVocabulary = [
        "shift", "roster", "rota", "clock in", "my hours", "when i work", "deputy", "7shifts", "homebase",
        "hotschedules", "sling", "workday", "kronos", "ukg", "humanity", "schedule source",
    ]

    // MARK: - Extraction

    /// Whether a screenshot reads as a schedule (two or more dated entries). Used to check the
    /// Premium entitlement before any events are created.
    static func detects(_ result: OCRResult, locale: Locale, anchor: Date, calendar: Calendar) -> Bool {
        extract(from: result, locale: locale, anchor: anchor, assetIdentifier: "", calendar: calendar) != nil
    }

    static func extract(
        from result: OCRResult,
        locale: Locale,
        anchor: Date,
        assetIdentifier: String,
        calendar: Calendar
    ) -> [ExtractedCandidateData]? {
        let lines = result.lines
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !DateInference.isDeadlineLine($0) }
        let weekStart = lines.lazy.compactMap { weekStartDate(in: $0, locale: locale, anchor: anchor, calendar: calendar) }.first

        var entries: [Entry] = []
        var offDays = 0
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let dates = dates(in: line, locale: locale, anchor: anchor, calendar: calendar, weekStart: weekStart)
            guard !dates.isEmpty else {
                index += 1
                continue
            }
            // A day range ("Oct 12-14") is one event spanning days: leave it to the regular path.
            if dates.contains(where: \.isRange) { return nil }

            // The entry's body: the rest of this line, plus following lines when this line holds
            // only the date (scheduling apps put the time and role on the lines below).
            var remainder = strippingDates(from: line)
            var body = [remainder]
            var next = index + 1
            if cleaned(remainder).isEmpty && timeRange(in: remainder) == nil && singleTimeStart(in: remainder) == nil {
                while next < lines.count, next - index <= 3,
                      self.dates(in: lines[next], locale: locale, anchor: anchor, calendar: calendar, weekStart: weekStart).isEmpty {
                    body.append(lines[next])
                    next += 1
                }
                remainder = body.joined(separator: "\n")
            }

            if body.contains(where: { isDayOff($0) }) {
                offDays += dates.count
            } else {
                let times = timeRange(in: remainder) ?? singleTimeStart(in: remainder).map { ($0, nil) }
                let label = body.lazy.map(cleaned).first(where: { !$0.isEmpty && !isDayOff($0) })
                for date in dates {
                    entries.append(Entry(
                        date: date.date,
                        hasExplicitYear: date.hasExplicitYear,
                        resolvedFromWeekday: date.fromWeekday,
                        start: times?.0,
                        end: times?.1,
                        label: label,
                        source: ([line] + body.dropFirst()).joined(separator: "\n")
                    ))
                }
            }
            index = max(next, index + 1)
        }

        guard entries.count + offDays >= 2, !entries.isEmpty else { return nil }

        let fullText = result.fullText
        let lower = fullText.lowercased()
        let rangedEntries = entries.filter { $0.start != nil && $0.end != nil }.count
        let isWorkSchedule = workVocabulary.contains { lower.contains($0) }
            || (lower.contains("schedule") && rangedEntries >= 2)

        let headline = DateInference.inferTitleFromHierarchy(lines: result.lines, fullText: fullText)
        let place = isWorkSchedule
            ? (venue: String?.none, address: String?.none)
            : DateInference.extractLocationAndVenue(lines: result.lines, fullText: fullText, excludingTitle: headline.title)
        let timeZone = DateInference.extractTimezone(from: fullText)

        return entries.map { entry in
            makeCandidate(
                entry,
                isWorkSchedule: isWorkSchedule,
                headline: headline,
                venue: place.venue,
                address: place.address,
                timeZone: timeZone,
                assetIdentifier: assetIdentifier,
                calendar: calendar
            )
        }
    }

    // MARK: - Candidate

    private static func makeCandidate(
        _ entry: Entry,
        isWorkSchedule: Bool,
        headline: DateInference.TitleInferenceResult,
        venue: String?,
        address: String?,
        timeZone: String?,
        assetIdentifier: String,
        calendar: Calendar
    ) -> ExtractedCandidateData {
        let segments = entry.label.map(labelSegments) ?? []
        let title: String
        let titleScore: Float
        var location = address
        if isWorkSchedule {
            title = segments.first.map { "Work shift · \($0)" } ?? "Work shift"
            titleScore = 0.8
            if segments.count > 1 { location = segments.dropFirst().joined(separator: " · ") }
        } else if let label = entry.label {
            title = label
            titleScore = 0.75
        } else {
            title = headline.title
            titleScore = headline.confidence
        }

        let start = entry.start.flatMap { calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: entry.date) } ?? entry.date
        var end: Date?
        if let clock = entry.end, var finish = calendar.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: entry.date) {
            if finish <= start { finish = calendar.date(byAdding: .day, value: 1, to: finish) ?? finish }
            end = finish
        } else if entry.start != nil {
            end = EventDurationPolicy.fallbackEnd(for: start)
        }

        let dateConfidence: Float = (entry.resolvedFromWeekday ? 0.85 : 0.9) * (entry.hasExplicitYear ? 1 : 0.95)
        let overall = max(0.4, min(0.97, Float(pow(Double(dateConfidence), 0.6) * pow(Double(titleScore), 0.4))))
        return ExtractedCandidateData(
            id: UUID().uuidString,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: entry.start == nil,
            location: location,
            venueName: isWorkSchedule ? nil : venue,
            rsvpUrl: nil,
            confidenceScore: overall,
            yearAssumed: !entry.hasExplicitYear,
            rawTextSnippet: entry.source,
            dateConfidence: dateConfidence,
            titleConfidence: titleScore,
            confidenceTierRaw: ConfidenceTier.from(score: overall).rawValue,
            isAmbiguousDate: false,
            ambiguousFragment: nil,
            timeZoneIdentifier: timeZone,
            dedupeKey: DateInference.computeDedupeKey(
                title: title, startDate: start, venueOrLocation: venue ?? location,
                assetIdentifier: assetIdentifier, calendar: calendar
            ),
            phoneNumber: nil,
            email: nil,
            notes: ""
        )
    }

    // MARK: - Dates

    private struct FoundDate {
        var date: Date
        var hasExplicitYear: Bool
        var fromWeekday: Bool
        var isRange: Bool
    }

    private static func dates(in line: String, locale: Locale, anchor: Date, calendar: Calendar, weekStart: Date?) -> [FoundDate] {
        guard weekOf.firstMatch(in: line, range: nsRange(line)) == nil else { return [] }
        var found: [FoundDate] = []
        for match in monthDay.matches(in: line, range: nsRange(line)) {
            guard let monthNumber = monthNumber(group(match, 1, in: line)), let day = Int(group(match, 2, in: line) ?? "") else { continue }
            let year = Int(group(match, 4, in: line) ?? "")
            if let date = resolve(month: monthNumber, day: day, year: year, anchor: anchor, calendar: calendar) {
                found.append(FoundDate(date: date, hasExplicitYear: year != nil, fromWeekday: false, isRange: group(match, 3, in: line) != nil))
            }
        }
        if found.isEmpty {
            for match in dayMonth.matches(in: line, range: nsRange(line)) {
                guard let day = Int(group(match, 1, in: line) ?? ""), let monthNumber = monthNumber(group(match, 2, in: line)) else { continue }
                let year = Int(group(match, 3, in: line) ?? "")
                if let date = resolve(month: monthNumber, day: day, year: year, anchor: anchor, calendar: calendar) {
                    found.append(FoundDate(date: date, hasExplicitYear: year != nil, fromWeekday: false, isRange: false))
                }
            }
        }
        if found.isEmpty {
            let monthFirst = isMonthFirst(locale)
            for match in numeric.matches(in: line, range: nsRange(line)) {
                guard let first = Int(group(match, 1, in: line) ?? ""), let second = Int(group(match, 2, in: line) ?? "") else { continue }
                var year = Int(group(match, 3, in: line) ?? "")
                if let short = year, short < 100 { year = 2000 + short }
                let (monthNumber, day) = monthFirst ? (first, second) : (second, first)
                if let date = resolve(month: monthNumber, day: day, year: year, anchor: anchor, calendar: calendar) {
                    found.append(FoundDate(date: date, hasExplicitYear: year != nil, fromWeekday: false, isRange: false))
                }
            }
        }
        if found.isEmpty, let weekStart, let match = leadingWeekday.firstMatch(in: line, range: nsRange(line)),
           let weekday = weekdayNumber(group(match, 1, in: line)),
           let date = calendar.nextDate(after: calendar.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart,
                                        matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime) {
            found.append(FoundDate(date: calendar.startOfDay(for: date), hasExplicitYear: false, fromWeekday: true, isRange: false))
        }
        return found
    }

    private static func weekStartDate(in line: String, locale: Locale, anchor: Date, calendar: Calendar) -> Date? {
        guard let match = weekOf.firstMatch(in: line, range: nsRange(line)),
              let range = Range(match.range, in: line) else { return nil }
        let tail = String(line[range.upperBound...])
        return dates(in: tail, locale: locale, anchor: anchor, calendar: calendar, weekStart: nil).first?.date
    }

    /// A date without a year goes to the year that puts it nearest the scan, so shifts earlier this
    /// week stay this year and dates just after New Year move forward.
    private static func resolve(month: Int, day: Int, year: Int?, anchor: Date, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        if let year {
            return calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
        let anchorYear = calendar.component(.year, from: anchor)
        return [anchorYear - 1, anchorYear, anchorYear + 1]
            .compactMap { calendar.date(from: DateComponents(year: $0, month: month, day: day)) }
            .filter { calendar.component(.day, from: $0) == day }
            .min { abs($0.timeIntervalSince(anchor)) < abs($1.timeIntervalSince(anchor)) }
    }

    // MARK: - Times

    private static func timeRange(in text: String) -> (Clock, Clock?)? {
        guard let match = timeRange.firstMatch(in: text, range: nsRange(text)),
              let startHour = Int(group(match, 1, in: text) ?? ""), let endHour = Int(group(match, 4, in: text) ?? "") else { return nil }
        let startMinute = Int(group(match, 2, in: text) ?? "") ?? 0
        let endMinute = Int(group(match, 5, in: text) ?? "") ?? 0
        let startMeridiem = meridiem(group(match, 3, in: text))
        let endMeridiem = meridiem(group(match, 6, in: text))
        guard (0...59).contains(startMinute), (0...59).contains(endMinute) else { return nil }

        let rawStart = group(match, 1, in: text) ?? ""
        let isTwentyFourHour = startMeridiem == nil && endMeridiem == nil
            && (startHour > 12 || endHour > 12 || rawStart.hasPrefix("0"))
        // A bare "9-5" with no minutes or meridiem is too ambiguous to read as a time.
        if startMeridiem == nil && endMeridiem == nil && group(match, 2, in: text) == nil && group(match, 5, in: text) == nil && !isTwentyFourHour {
            return nil
        }
        guard (0...23).contains(startHour), (0...23).contains(endHour) else { return nil }

        if isTwentyFourHour {
            return (Clock(hour: startHour, minute: startMinute), Clock(hour: endHour, minute: endMinute))
        }
        let end = Clock(hour: to24(endHour, endMeridiem ?? inferredMeridiem(for: endHour)), minute: endMinute)
        var startHour24: Int
        if let startMeridiem {
            startHour24 = to24(startHour, startMeridiem)
        } else if let endMeridiem {
            // "11-7pm" starts in the morning; "1-5pm" shares the end's meridiem.
            startHour24 = to24(startHour, endMeridiem)
            if startHour24 * 60 + startMinute >= end.hour * 60 + end.minute { startHour24 = to24(startHour, endMeridiem == "p" ? "a" : "p") }
        } else {
            startHour24 = to24(startHour, inferredMeridiem(for: startHour))
        }
        return (Clock(hour: startHour24, minute: startMinute), end)
    }

    private static func singleTimeStart(in text: String) -> Clock? {
        guard let match = singleTime.firstMatch(in: text, range: nsRange(text)) else { return nil }
        if group(match, 4, in: text) != nil { return Clock(hour: 12, minute: 0) }
        guard let hour = Int(group(match, 1, in: text) ?? ""), let marker = meridiem(group(match, 3, in: text)) else { return nil }
        let minute = Int(group(match, 2, in: text) ?? "") ?? 0
        guard (1...12).contains(hour), (0...59).contains(minute) else { return nil }
        return Clock(hour: to24(hour, marker), minute: minute)
    }

    private static func meridiem(_ raw: String?) -> String? {
        guard let first = raw?.lowercased().first else { return nil }
        return first == "a" ? "a" : first == "p" ? "p" : nil
    }

    /// Without am/pm, 7–11 read as morning and 12–6 as afternoon, typical for shifts and events.
    private static func inferredMeridiem(for hour: Int) -> String {
        (7...11).contains(hour) ? "a" : "p"
    }

    private static func to24(_ hour: Int, _ marker: String) -> Int {
        let base = hour % 12
        return marker == "p" ? base + 12 : base
    }

    // MARK: - Text Cleanup

    private static func strippingDates(from line: String) -> String {
        var text = line
        for regex in [monthDay, dayMonth, numeric] {
            text = regex.stringByReplacingMatches(in: text, range: nsRange(text), withTemplate: " ")
        }
        return text
    }

    /// The entry's own words: no weekdays, times, or leftover punctuation.
    private static func cleaned(_ text: String) -> String {
        var value = weekdayWords.stringByReplacingMatches(in: text, range: nsRange(text), withTemplate: " ")
        value = timeRange.stringByReplacingMatches(in: value, range: nsRange(value), withTemplate: " ")
        value = singleTime.stringByReplacingMatches(in: value, range: nsRange(value), withTemplate: " ")
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return value.trimmingCharacters(in: CharacterSet(charactersIn: " ,·•|:;-–—()").union(.whitespaces))
    }

    private static func labelSegments(_ label: String) -> [String] {
        label.components(separatedBy: CharacterSet(charactersIn: "·•|"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func isDayOff(_ text: String) -> Bool {
        dayOff.firstMatch(in: cleaned(text), range: nsRange(cleaned(text))) != nil
            || dayOff.firstMatch(in: text, range: nsRange(text)) != nil
    }

    // MARK: - Helpers

    private static func isMonthFirst(_ locale: Locale) -> Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "Md", options: 0, locale: locale) ?? "M/d"
        guard let monthIndex = format.firstIndex(of: "M"), let dayIndex = format.firstIndex(of: "d") else { return true }
        return monthIndex < dayIndex
    }

    private static func monthNumber(_ raw: String?) -> Int? {
        guard let prefix = raw?.lowercased().prefix(3) else { return nil }
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: String(prefix)).map { $0 + 1 }
    }

    private static func weekdayNumber(_ raw: String?) -> Int? {
        guard let prefix = raw?.lowercased().prefix(3) else { return nil }
        let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return days.firstIndex(of: String(prefix)).map { $0 + 1 }
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return nil }
        return String(text[range])
    }

    private static func nsRange(_ text: String) -> NSRange {
        NSRange(location: 0, length: text.utf16.count)
    }
}
