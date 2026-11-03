---
name: pencild-conflict-triage
description: Use for calendar overlap detection, the save-time and batch conflict preflight, duplicate events across screenshots, and multi-date / multi-shift schedule splitting in Pencil'd. Not for duration defaults or paywall copy.
---

You own conflict, duplicate, and multi-event handling in the Pencil'd iOS app. Read `CLAUDE.md` and `AGENTS.md` first.

## Scope & Code Seams
- Conflicts:
  - `Sources/Pencild/Services/CalendarService.swift`: save-time and batch conflict preflight (`verifyEventKitState`, `saveEvent`).
  - `Sources/Pencild/Services/Intelligence/EventDurationPolicy.swift`: `ScheduleInterval` (line 33), `ScheduleConflict` (line 52), and `ScheduleConflictAnalyzer` (line 69).
  - `Sources/Pencild/Models/AppState.swift`: `activeConflictContext: ConflictResolutionContext?` (line 54).
  - `Sources/Pencild/Views/ConflictResolutionView.swift`: conflict dialog presentation.
- Duplicates:
  - `Sources/Pencild/Services/Advisors/EventSimilarityService.swift`: `matches(for:among:)` (line 42), `clusters(_:)` (line 55), `premiumClusters(_:)` (line 70).
  - `Sources/Pencild/Services/EventExtractionService.swift`: `computeDedupeKey` (line 210).
- Schedules & Multi-Event:
  - `Sources/Pencild/Services/ScheduleExtractor.swift`: schedule row detection, parsing, and shift generation (`extract`).
  - `Sources/Pencild/ViewModels/BatchScanViewModel.swift`: batch session processing and error aggregation.
- Tests:
  - `Tests/PencildTests/CalendarServiceTests.swift`
  - `Tests/PencildTests/BatchScanTests.swift`
  - `Tests/PencildTests/ScheduleExtractionTests.swift`
  - `Tests/PencildTests/ScheduleGatingTests.swift`
  - `Tests/PencildTests/AdvisorTests.swift`

## Rules
- Harden and extend the existing code. Don't add a parallel system.
- Conflict behavior depends on where the event came from (`EventCandidate.isManualEntry`, exposed as `EventReviewViewModel.isManualEntry`):
  - **Scanned events** (`isManualEntry == false`): flag the overlap and let the user choose to save anyway, edit the time, or pick another calendar. Never suggest a different time, because flyer times are set by the organizer.
  - **Manually entered events** (`isManualEntry == true`, including the form prefilled from "No dates found"): flag the overlap and also suggest alternatives. Offer up to 3 open slots that keep the event's duration, first later on the same day and then the following days. Base them on the user's calendars as read through `CalendarService`, respect the `insufficientGap` buffer, and never propose a slot in the past. Show them as tappable options. Choosing one only updates the form, and the user still reviews and saves. "Save anyway" stays available. All-day events get alternative dates, and deadlines get no suggestions.
- Slot finding stays on device (EventKit only) and is a pure, testable function with an injected calendar and "now".
- Batches never drop an item silently. Every skipped, merged, or deduped item stays visible with its reason.
- Archive-wide duplicate clusters and schedule import are Premium (`PremiumFeature.duplicateClusters`, `.scheduleImport`). Keep the controls visible and open the paywall on tap. Never compute and show paid results to free users.
- Cover these edge cases with tests: all-day vs timed events, cross-midnight shifts, DST and time zones, the same flyer captured in two screenshots, back-to-back events (touching is not overlapping), and the `insufficientGap` threshold. For alternatives, also test: a manual entry gets slots and a scanned one gets none; the duration is preserved; past slots are excluded; a fully booked day rolls over to the next day; an all-day event gets dates; a deadline gets nothing.

## Prompt Grounding Standards
When generating or handing off task prompts to be implemented by this agent, ensure the prompt explicitly provides:
1. **Concrete Objective:** Specific conflict, deduplication, or schedule splitting requirement.
2. **Exact Files and Method Seams with Line Numbers:** e.g., modifying `ScheduleConflictAnalyzer.conflicts` in `Sources/Pencild/Services/Intelligence/EventDurationPolicy.swift` or `CalendarService.saveEvent` in `Sources/Pencild/Services/CalendarService.swift`.
3. **Expected Outcomes:** Concrete data structures returned (e.g., `[ScheduleConflict]`), precise behavior for scanned vs. manual events, and batch status invariants (no silent drops).
4. **Repository Conventions:**
   - Swift 6 strict concurrency (`Sendable`-correct, no data races).
   - Warnings treated as errors.
   - Prohibit `print` (use `os.Logger` if needed).
   - Prohibit force unwraps (`!`).
   - Prohibit `TODO`/`FIXME`/`HACK`/`XXX` markers in `Sources/`.
   - Never edit `Pencild.xcodeproj` directly.
   - Preserve brand identity (`Pencil'd` / `Pencild`).
5. **Testing & Verification Commands:**
   - Swift Testing assertions with `#expect(...)`.
   - Unit test command: `xcodebuild test -project Pencild.xcodeproj -scheme Pencild -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PencildTests/CalendarServiceTests`.

## Done means
The app target builds with warnings as errors, and the related suites pass (`CalendarServiceTests`, `BatchScanTests`, `ScheduleExtractionTests`, `ScheduleGatingTests`, `AdvisorTests`), run with `-only-testing:PencildTests/<Suite>`.
