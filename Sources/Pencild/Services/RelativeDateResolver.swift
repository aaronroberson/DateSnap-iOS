import Foundation

/// Resolves relative temporal phrases (e.g. "today", "tonight", "tomorrow", "in 3 days", "this Friday", "next Monday")
/// relative to a reference anchor date and calendar.
public enum RelativeDateResolver {

    public struct RelativeResult: Sendable, Equatable {
        public var date: Date
        public var hasExplicitTime: Bool

        public init(date: Date, hasExplicitTime: Bool) {
            self.date = date
            self.hasExplicitTime = hasExplicitTime
        }
    }

    private static let weekdays: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
        "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7
    ]

    private static let inDaysRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\bin\\s+(\\d+)\\s+days?\\b")
    private static let inWeeksRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\bin\\s+(\\d+)\\s+weeks?\\b")
    private static let weekdayRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?:this|coming|next)\\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)"
    )

    /// Resolves relative date phrases within the given text.
    public static func resolve(in text: String, anchor: Date, calendar: Calendar = .current) -> RelativeResult? {
        let lower = text.lowercased()

        if let tonight = resolveTonight(in: lower, anchor: anchor, calendar: calendar) {
            return tonight
        }

        if let today = resolveToday(in: lower, anchor: anchor) {
            return today
        }

        if let tomorrow = resolveTomorrow(in: lower, anchor: anchor, calendar: calendar) {
            return tomorrow
        }

        if let inDays = resolveInDays(in: lower, anchor: anchor, calendar: calendar) {
            return inDays
        }

        if let inWeeks = resolveInWeeks(in: lower, anchor: anchor, calendar: calendar) {
            return inWeeks
        }

        if let relativeWeekday = resolveRelativeWeekday(in: lower, anchor: anchor, calendar: calendar) {
            return relativeWeekday
        }

        return nil
    }

    // MARK: - Granular Phrase Resolvers

    /// Resolves "tonight" phrases with explicit time set to 19:00.
    public static func resolveTonight(in lowerText: String, anchor: Date, calendar: Calendar = .current) -> RelativeResult? {
        guard lowerText.contains("tonight") else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: anchor)
        comps.hour = 19
        comps.minute = 0
        let d = calendar.date(from: comps) ?? anchor
        return RelativeResult(date: d, hasExplicitTime: true)
    }

    /// Resolves "today" phrases without explicit time.
    public static func resolveToday(in lowerText: String, anchor: Date) -> RelativeResult? {
        guard lowerText.contains("today") else { return nil }
        return RelativeResult(date: anchor, hasExplicitTime: false)
    }

    /// Resolves "tomorrow" or "tmrw" phrases.
    public static func resolveTomorrow(in lowerText: String, anchor: Date, calendar: Calendar = .current) -> RelativeResult? {
        guard lowerText.contains("tomorrow") || lowerText.contains("tmrw") else { return nil }
        let nextDay = calendar.date(byAdding: .day, value: 1, to: anchor) ?? anchor
        return RelativeResult(date: nextDay, hasExplicitTime: false)
    }

    /// Resolves "in N days" expressions.
    public static func resolveInDays(in lowerText: String, anchor: Date, calendar: Calendar = .current) -> RelativeResult? {
        guard let regex = inDaysRegex,
              let match = regex.firstMatch(in: lowerText, range: NSRange(location: 0, length: lowerText.utf16.count)),
              let r = Range(match.range(at: 1), in: lowerText),
              let n = Int(lowerText[r]) else {
            return nil
        }
        let target = calendar.date(byAdding: .day, value: n, to: anchor) ?? anchor
        return RelativeResult(date: target, hasExplicitTime: false)
    }

    /// Resolves "in N weeks" expressions.
    public static func resolveInWeeks(in lowerText: String, anchor: Date, calendar: Calendar = .current) -> RelativeResult? {
        guard let regex = inWeeksRegex,
              let match = regex.firstMatch(in: lowerText, range: NSRange(location: 0, length: lowerText.utf16.count)),
              let r = Range(match.range(at: 1), in: lowerText),
              let n = Int(lowerText[r]) else {
            return nil
        }
        let target = calendar.date(byAdding: .weekOfYear, value: n, to: anchor) ?? anchor
        return RelativeResult(date: target, hasExplicitTime: false)
    }

    /// Resolves "this/coming <weekday>" vs "next <weekday>".
    public static func resolveRelativeWeekday(in lowerText: String, anchor: Date, calendar: Calendar = .current) -> RelativeResult? {
        guard let regex = weekdayRegex,
              let match = regex.firstMatch(in: lowerText, range: NSRange(location: 0, length: lowerText.utf16.count)) else {
            return nil
        }

        let fullMatched = (lowerText as NSString).substring(with: match.range)
        let nameMatched = (lowerText as NSString).substring(with: match.range(at: 1))

        guard let targetWeekday = weekdays[nameMatched] else { return nil }
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
