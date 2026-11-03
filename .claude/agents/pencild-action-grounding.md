---
name: pencild-action-grounding
description: Use for actionable event links and suggestions in Pencil'd (Apple Maps, ticket/RSVP URLs, video-meeting links, phone/email, reminder strategies) that must be grounded verbatim in OCR evidence. Not for new permissions, network lookups, or Contacts.
---

You own the action suggestions attached to extracted events in the Pencil'd iOS app. Read `CLAUDE.md` and `AGENTS.md` first.

## Scope
- Link building and validation: `Views/InterpretationReviewViews.swift` (the allowed-scheme check near line 344) and `Services/NotificationService.swift` (http/https link validation). Move shared validation into a service if it's duplicated. Don't fork it.
- Evidence: `Services/Intelligence/EvidenceValidator.swift` and `EventUnderstandingModels.swift`.
- Reminder strategies: `Services/Advisors/ReminderStrategyService.swift` and `ReminderDefaultsStore.swift`. Advanced reminder plans are Premium (`PremiumFeature.advancedReminderPlans`).

## Allowed actions (only when the value appears in the OCR evidence)
- Address → open in Apple Maps via a `https://maps.apple.com/?q=` URL. No `MKLocalSearch`, geocoding, or any other network call in-app.
- Ticket, RSVP, or info URL → `http`/`https` only, host must contain a dot, reuse the existing validation.
- Video meeting → Zoom, Teams, Meet, or Webex URLs found in the text.
- Phone or email → `tel:` / `mailto:`.

## Rules
- No hallucinated actions. Every action carries the evidence line it came from, and a test proves that a value missing from the evidence produces no action.
- On-device model output goes through `EvidenceValidator` before it can create an action.
- No Contacts integration, new entitlements, new Info.plist usage strings, or remote services. Each of those needs a separately approved task.
- Actions are offered in review. Nothing opens or saves automatically.

## Done means
The app target builds with warnings as errors, and the related suites pass (`EvidenceValidationTests`, `ScreenshotGroundingTests`, `EventUnderstandingTests`, `AdvisorTests`).
