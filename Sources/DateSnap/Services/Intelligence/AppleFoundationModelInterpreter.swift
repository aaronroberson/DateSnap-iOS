import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Apple Intelligence Capability

/// Maps `SystemLanguageModel` availability (OS, device, Apple Intelligence setting, model readiness and
/// language) to DateSnap's capability. Queried per scan; never cached.
@available(iOS 26.0, macOS 26.0, *)
struct AppleIntelligenceCapabilityProvider: IntelligenceCapabilityProviding {
    func currentCapability(for locale: Locale) -> IntelligenceCapability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(locale) ? .available : .unavailable(.languageUnsupported)
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled: return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady: return .unavailable(.modelNotReady)
            @unknown default: return .unavailable(.unknown)
            }
        @unknown default:
            return .unavailable(.unknown)
        }
    }
}

// MARK: - Constrained Output Schema

/// One event, expressed as references to numbered OCR lines. Names are taken from the referenced line by the
/// validator, so the model only copies the short time strings.
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "One event on the flyer, described only by referencing numbered OCR lines.")
struct GeneratedEvent {
    @Guide(description: "Line number of the event's name (not a tagline, venue, sponsor or series name).")
    var titleLine: Int?
    @Guide(description: "Line number naming the venue or place, if any.")
    var venueLine: Int?
    @Guide(description: "Line number naming a separate organizer or presenter, if any.")
    var organizerLine: Int?
    @Guide(description: "Line number containing this event's calendar date. Not an RSVP deadline or ticket on-sale date.")
    var dateLine: Int?
    @Guide(description: "Line number with the time the main event starts: the show, headliner or performance, not doors or arrival.")
    var startTimeLine: Int?
    @Guide(description: "The start time copied exactly from startTimeLine, e.g. '8:30 PM'.")
    var startTime: String?
    @Guide(description: "Line number with an earlier doors, opening or arrival time, if printed.")
    var doorsTimeLine: Int?
    @Guide(description: "The doors time copied exactly from doorsTimeLine.")
    var doorsTime: String?
    @Guide(description: "Line number with an explicit end time, if printed.")
    var endTimeLine: Int?
    @Guide(description: "The end time copied exactly from endTimeLine.")
    var endTime: String?
    @Guide(description: "One of: concert, nightlife, conference, appointment, sports, festival, classOrWorkshop, social, deadline, other.")
    var category: String?
    @Guide(description: "A few words citing the label that identifies the start time.")
    var reason: String?
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Events described on the flyer, in the same order as the detected events listed in the prompt.")
struct GeneratedEventList {
    @Guide(description: "One entry per detected event, in the same order.")
    var events: [GeneratedEvent]
}

// MARK: - Interpreter

/// On-device semantic pass over OCR lines. The actor isolates session state; a fresh session per scan keeps
/// context bounded, and the actor serializes scans so sessions never run concurrently.
@available(iOS 26.0, macOS 26.0, *)
actor AppleFoundationModelInterpreter: OnDeviceEventInterpreting {
    static let instructions = """
    You label text recognized from an event flyer or screenshot. Each line is numbered.
    Only reference line numbers that appear in the list, and copy text exactly from the referenced line.
    Never invent dates, times, places, names, links, emails or phone numbers. Leave a field empty when the flyer does not state it.
    Distinguish the event's own date from RSVP deadlines and ticket on-sale dates, and the show start from doors or arrival times.
    """

    /// Loads the model ahead of the first request (called when a scan starts OCR).
    func prewarm() {
        LanguageModelSession(instructions: Self.instructions).prewarm()
    }

    func interpret(_ request: InterpretationRequest) async throws -> [EventHypothesis] {
        try Task.checkCancellation()
        let session = LanguageModelSession(instructions: Self.instructions)
        let options = GenerationOptions(temperature: 0, maximumResponseTokens: 400)
        let response = try await session.respond(to: Self.prompt(for: request), generating: GeneratedEventList.self, options: options)
        try Task.checkCancellation()
        return response.content.events.prefix(max(1, request.baseline.count)).map(Self.hypothesis(from:))
    }

    static func prompt(for request: InterpretationRequest) -> String {
        let lines = request.lines
            .map { "[\($0.id)] \($0.text)  (size rank \($0.fontRank + 1))" }
            .joined(separator: "\n")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy HH:mm"
        let detected = request.baseline.enumerated().map { index, candidate in
            "\(index + 1). \"\(candidate.title.value)\" on \(formatter.string(from: candidate.start.value))"
        }.joined(separator: "\n")
        return """
        Today is \(formatter.string(from: request.referenceDate)) in time zone \(request.timeZoneIdentifier); locale \(request.localeIdentifier).
        Detected events (from rules, may be wrong):
        \(detected)
        Why a second look is needed: \(request.triggers.joined(separator: ", ")).

        Flyer lines:
        \(lines)
        """
    }

    static func hypothesis(from event: GeneratedEvent) -> EventHypothesis {
        EventHypothesis(
            titleLineID: event.titleLine,
            venueLineID: event.venueLine,
            organizerLineID: event.organizerLine,
            dateLineID: event.dateLine,
            startTimeLineID: event.startTimeLine, startTimeText: event.startTime,
            doorsTimeLineID: event.doorsTimeLine, doorsTimeText: event.doorsTime,
            endTimeLineID: event.endTimeLine, endTimeText: event.endTime,
            category: event.category, reason: event.reason
        )
    }
}
#endif
