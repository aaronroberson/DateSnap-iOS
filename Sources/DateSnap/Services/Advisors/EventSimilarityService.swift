import Foundation

// MARK: - Event Similarity
/// Finds events that may be the same as a new candidate across different screenshots. Suggestions only:
/// nothing is merged or deleted automatically, and each record keeps its own source scan.
public enum EventSimilarityService {
    public struct Entry: Sendable, Hashable {
        public var id: String
        public var similarityKey: String
        public var title: String
        public var start: Date
        public var isSaved: Bool

        public init(id: String, similarityKey: String, title: String, start: Date, isSaved: Bool) {
            self.id = id
            self.similarityKey = similarityKey
            self.title = title
            self.start = start
            self.isSaved = isSaved
        }
    }

    public struct Match: Sendable, Hashable {
        public var entry: Entry
        public var reason: String
    }

    /// Same content key, or the same day with mostly the same title words.
    public static func matches(for candidate: Entry, among entries: [Entry], calendar: Calendar = .current) -> [Match] {
        entries.compactMap { other in
            guard other.id != candidate.id else { return nil }
            if !candidate.similarityKey.isEmpty && other.similarityKey == candidate.similarityKey {
                return Match(entry: other, reason: "Same title, day and venue")
            }
            guard calendar.isDate(other.start, inSameDayAs: candidate.start) else { return nil }
            let overlap = titleOverlap(candidate.title, other.title)
            return overlap >= 0.6 ? Match(entry: other, reason: "Same day, similar title") : nil
        }
    }

    /// Groups entries into clusters of likely duplicates (connected by `matches`). Singletons are omitted.
    public static func clusters(_ entries: [Entry], calendar: Calendar = .current) -> [[Entry]] {
        var remaining = entries
        var clusters: [[Entry]] = []
        while let seed = remaining.first {
            remaining.removeFirst()
            var cluster = [seed]
            var frontier = [seed]
            while let current = frontier.popLast() {
                let found = matches(for: current, among: remaining, calendar: calendar).map(\.entry)
                remaining.removeAll { entry in found.contains { $0.id == entry.id } }
                cluster += found
                frontier += found
            }
            if cluster.count > 1 { clusters.append(cluster) }
        }
        return clusters
    }

    static func titleOverlap(_ a: String, _ b: String) -> Double {
        let wordsA = Set(DateInference.normalizeText(a).split(separator: " ").filter { $0.count > 1 })
        let wordsB = Set(DateInference.normalizeText(b).split(separator: " ").filter { $0.count > 1 })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return 0 }
        return Double(wordsA.intersection(wordsB).count) / Double(wordsA.union(wordsB).count)
    }
}
