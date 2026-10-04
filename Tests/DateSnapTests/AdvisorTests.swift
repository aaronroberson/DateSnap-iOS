import Foundation
import Testing
@testable import DateSnap

@Suite("Cross-service advisors")
struct AdvisorTests {
    @Test("Entitlements gate convenience features only, by tier")
    func entitlements() {
        #expect(!SubscriptionTier.starter.includes(.automaticScreenshotDetection))
        #expect(SubscriptionTier.plus.includes(.automaticScreenshotDetection))
        #expect(SubscriptionTier.plus.includes(.likelyEventTriage))
        #expect(!SubscriptionTier.plus.includes(.documentImport))
        #expect(SubscriptionTier.premium.includes(.advancedReminderPlans))
        #expect(PremiumFeature.allCases.allSatisfy { SubscriptionTier.premium.includes($0) })
    }
}

@Suite("Reminder strategy, similarity and calendar advisors")
struct AdvisorServiceTests {
    let now = testAnchor

    @Test("Plans use supported offsets, respect lead time and add deadline reminders")
    func reminderPlan() {
        let start = now.addingTimeInterval(86400 * 10)
        let appointment = ReminderStrategyService.plan(category: .appointment, start: start, isAllDay: false, rsvpDeadline: nil, now: now)
        #expect(appointment.offsets == [.oneDayBefore, .oneHourBefore])
        #expect(appointment.offsets.allSatisfy { ReminderOffset.catalog.contains($0) })

        let soon = ReminderStrategyService.plan(category: .concert, start: now.addingTimeInterval(3600), isAllDay: false, rsvpDeadline: nil, now: now)
        #expect(soon.offsets == [.thirtyMinutesBefore])

        let deadline = now.addingTimeInterval(86400 * 5)
        let withDeadline = ReminderStrategyService.plan(category: .social, start: start, isAllDay: false, rsvpDeadline: deadline, now: now)
        let reminder = withDeadline.deadlineReminder
        #expect(reminder != nil && reminder! < deadline && reminder! > now)

        let pastDeadline = ReminderStrategyService.plan(category: .social, start: start, isAllDay: false, rsvpDeadline: now.addingTimeInterval(-60), now: now)
        #expect(pastDeadline.deadlineReminder == nil)
        #expect(ReminderStrategyService.plan(category: .festival, start: start, isAllDay: false, rsvpDeadline: nil, now: now).offsets.count <= 3)
    }

    @Test("Similar events match across screenshots; different days don't")
    func similarity() {
        let day = now.addingTimeInterval(86400 * 3)
        let saved = EventSimilarityService.Entry(id: "a", similarityKey: "k1", title: "Neon Sunset Rooftop", start: day, isSaved: true)
        let sameKey = EventSimilarityService.Entry(id: "b", similarityKey: "k1", title: "NEON SUNSET", start: day, isSaved: false)
        let sameDayTitle = EventSimilarityService.Entry(id: "c", similarityKey: "k2", title: "Neon Sunset Rooftop Party", start: day.addingTimeInterval(1800), isSaved: false)
        let otherDay = EventSimilarityService.Entry(id: "d", similarityKey: "k3", title: "Neon Sunset Rooftop", start: day.addingTimeInterval(86400 * 7), isSaved: false)
        #expect(EventSimilarityService.matches(for: sameKey, among: [saved, otherDay]).map(\.entry.id) == ["a"])
        #expect(EventSimilarityService.matches(for: sameDayTitle, among: [saved]).count == 1)
        #expect(EventSimilarityService.matches(for: otherDay, among: [saved]).isEmpty)
        let clusters = EventSimilarityService.clusters([saved, sameKey, sameDayTitle, otherDay])
        #expect(clusters.count == 1)
        #expect(Set(clusters[0].map(\.id)) == ["a", "b", "c"])
    }

    @Test("Calendar suggestions follow the user's own choices per category")
    func calendarRecommendation() {
        let service = CalendarRecommendationService(defaultsSuiteName: "datesnap.tests.\(UUID().uuidString)")
        #expect(service.suggestedCalendarIdentifier(for: .concert, available: ["work", "fun"]) == nil)
        service.recordChoice(calendarIdentifier: "fun", for: .concert)
        #expect(service.suggestedCalendarIdentifier(for: .concert, available: ["work", "fun"]) == "fun")
        #expect(service.suggestedCalendarIdentifier(for: .concert, available: ["work"]) == nil)
        #expect(service.suggestedCalendarIdentifier(for: .appointment, available: ["work", "fun"]) == nil)
    }
}

@Suite("Notification link actions")
struct NotificationLinkTests {
    @Test("Only http(s) links from the flyer become notification actions")
    func validatedLinks() {
        #expect(NotificationService.validatedLink("datesnap.app/rsvp")?.absoluteString == "https://datesnap.app/rsvp")
        #expect(NotificationService.validatedLink("https://tickets.example.com/e/1")?.host == "tickets.example.com")
        #expect(NotificationService.validatedLink("javascript:alert(1)") == nil)
        #expect(NotificationService.validatedLink("tel:5551234567") == nil)
        #expect(NotificationService.validatedLink("not a link") == nil)
        #expect(NotificationService.validatedLink("") == nil)
    }
}

@Suite("Intelligence usage policy")
struct IntelligenceUsagePolicyTests {
    @Test("Daily triage budgets depend on tier and reset each day")
    func budgets() {
        let policy = IntelligenceUsagePolicy(defaultsSuiteName: "datesnap.tests.usage.\(UUID().uuidString)")
        let day = testAnchor
        #expect(policy.consume(.likelyEventTriage, count: 5, tier: .starter, now: day) == 0)
        #expect(policy.consume(.likelyEventTriage, count: 25, tier: .plus, now: day) == 25)
        #expect(policy.consume(.likelyEventTriage, count: 10, tier: .plus, now: day) == 5)
        #expect(policy.consume(.likelyEventTriage, count: 1, tier: .plus, now: day) == 0)
        #expect(policy.consume(.likelyEventTriage, count: 6, tier: .plus, now: day.addingTimeInterval(86400)) == 6)
        #expect(policy.consume(.documentImport, count: 3, tier: .premium, now: day) == 3)
    }
}

@Suite("Event action link validation")
struct EventActionLinkValidationTests {
    @Test("Validates and restricts action link schemes to allowed set")
    @MainActor
    func actionLinkValidation() {
        // Call actions
        let validCall = ActionSuggestion(kind: .call, target: "+1 (555) 123-4567")
        #expect(EventActionsChecklist.validatedActionURL(for: validCall)?.absoluteString == "tel:+15551234567")

        let invalidCall = ActionSuggestion(kind: .call, target: "no-digits-here")
        #expect(EventActionsChecklist.validatedActionURL(for: invalidCall) == nil)

        // Email actions
        let validEmail = ActionSuggestion(kind: .email, target: "rsvp@example.com")
        #expect(EventActionsChecklist.validatedActionURL(for: validEmail)?.absoluteString == "mailto:rsvp@example.com")

        let invalidEmailWithSpaces = ActionSuggestion(kind: .email, target: "rsvp @ example.com")
        #expect(EventActionsChecklist.validatedActionURL(for: invalidEmailWithSpaces) == nil)

        let emptyEmail = ActionSuggestion(kind: .email, target: "")
        #expect(EventActionsChecklist.validatedActionURL(for: emptyEmail) == nil)

        // Web / RSVP / Ticket actions
        let validWeb = ActionSuggestion(kind: .website, target: "https://example.com/tickets")
        #expect(EventActionsChecklist.validatedActionURL(for: validWeb)?.absoluteString == "https://example.com/tickets")

        let validRSVP = ActionSuggestion(kind: .rsvp, target: "datesnap.app/rsvp")
        #expect(EventActionsChecklist.validatedActionURL(for: validRSVP)?.absoluteString == "https://datesnap.app/rsvp")

        // Malicious schemes
        let javascriptScheme = ActionSuggestion(kind: .website, target: "javascript:alert(1)")
        #expect(EventActionsChecklist.validatedActionURL(for: javascriptScheme) == nil)

        let fileScheme = ActionSuggestion(kind: .rsvp, target: "file:///etc/passwd")
        #expect(EventActionsChecklist.validatedActionURL(for: fileScheme) == nil)

        let dataScheme = ActionSuggestion(kind: .buyTickets, target: "data:text/html,<script>alert(1)</script>")
        #expect(EventActionsChecklist.validatedActionURL(for: dataScheme) == nil)
    }
}
