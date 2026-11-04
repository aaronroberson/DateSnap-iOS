---
name: pencild-action-grounding
description: Use for actionable event links and suggestions in Pencil'd (Apple Maps, ticket/RSVP URLs, video-meeting links, phone/email, reminder strategies) that must be grounded verbatim in OCR evidence. Not for new permissions, network lookups, or Contacts.
---

You own the action suggestions attached to extracted events in the Pencil'd iOS app. Read `CLAUDE.md` and `AGENTS.md` first.

## Scope & Code Seams
- Link Building and Validation:
  - `Sources/Pencild/Views/InterpretationReviewViews.swift`: `EventActionsChecklist` and `validatedActionURL`.
  - `Sources/Pencild/Services/NotificationService.swift`: http/https URL scheme and host validation.
- Evidence & Models:
  - `Sources/Pencild/Services/Intelligence/RuleBasedEventAnalyzer.swift`: `extractActions(in:temporal:)`, where deterministic actions are built from evidence lines.
  - `Sources/Pencild/Services/Intelligence/EvidenceValidator.swift`: validation of candidate properties against OCR evidence lines.
  - `Sources/Pencild/Services/Intelligence/EventUnderstandingModels.swift`: `ActionSuggestion` and `ActionSuggestion.Kind`.
- Reminder Strategies:
  - `Sources/Pencild/Services/Advisors/ReminderStrategyService.swift`: category-based reminder plans (`ReminderStrategyService.plan(category:start:isAllDay:rsvpDeadline:now:calendar:)`).
  - `Sources/Pencild/Services/Advisors/ReminderDefaultsStore.swift`: local user reminder defaults.
- Tests:
  - `Tests/PencildTests/EvidenceValidationTests.swift`
  - `Tests/PencildTests/ScreenshotGroundingTests.swift`
  - `Tests/PencildTests/EventUnderstandingTests.swift`
  - `Tests/PencildTests/AdvisorTests.swift`

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

## Handoffs
Prompts handed to this agent follow the shared standards in `AGENTS.md` ("Prompt Grounding Standards for Agent Handoffs"). Cite symbols, not line numbers.

## Done means
The app target builds with warnings as errors, and the related suites pass (`EvidenceValidationTests`, `ScreenshotGroundingTests`, `EventUnderstandingTests`, `AdvisorTests`).
