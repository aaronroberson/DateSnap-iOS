import Foundation
import SwiftData
import Testing
@testable import DateSnap

@Suite("Interpretation record persistence")
@MainActor
struct InterpretationRecordTests {
    func container() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Review bundles round-trip and are deleted with their candidate")
    func roundTripAndCascade() async throws {
        let ocr = makeOCR([("Book Club", 0.08), ("04/05/2027 7pm", 0.04), ("RSVP by March 30 at books.example.org", 0.03)])
        let result = await EventUnderstandingPipeline.rulesOnly(calendar: testCalendar).understand(ocr, locale: Locale(identifier: "en_001"), anchor: testAnchor)
        let understanding = try #require(result.events.first)
        #expect(!understanding.alternatives.isEmpty)

        let container = try container()
        let context = container.mainContext
        let candidate = understanding.best.toExtractedData().toModel()
        let record = try #require(InterpretationRecord.make(for: understanding, in: result))
        context.insert(candidate)
        context.insert(record)
        candidate.interpretation = record
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<EventCandidate>()).first)
        let stored = try #require(fetched.interpretation?.stored)
        #expect(stored.understanding.best.id == understanding.best.id)
        #expect(stored.understanding.alternatives.count == understanding.alternatives.count)
        #expect(stored.evidence.count == result.evidence.count)
        #expect(stored.understanding.actions.contains { $0.deadline != nil })

        context.delete(fetched)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<InterpretationRecord>()).isEmpty)
    }

    @Test("Records from a newer schema are ignored rather than misread")
    func futureSchemaIgnored() throws {
        let record = InterpretationRecord(schemaVersion: EventUnderstandingResult.schemaVersion + 1, engineRoute: "rulesOnly", payload: Data("{}".utf8))
        #expect(record.stored == nil)
    }
}
