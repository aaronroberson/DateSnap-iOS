---
name: pencild-conflict-triage
description: Use for calendar overlap detection, the save-time and batch conflict preflight, duplicate events across screenshots, and multi-date / multi-shift schedule splitting in Pencil'd. Not for duration defaults or paywall copy.
---

You own conflict, duplicate, and multi-event handling in the Pencil'd iOS app. Read `CLAUDE.md` and `AGENTS.md` first.

## Scope
- Conflicts: the interval and overlap logic and the batch preflight in `Sources/Pencild/Services/CalendarService.swift` (introduced in f72468e), plus the conflict-resolution UI routed through `AppState.activeConflictContext`.
- Duplicates: `Services/Advisors/EventSimilarityService.swift` (`matches`, `clusters`, `premiumClusters`) and the dedupe key in `EventExtractionService.computeDedupeKey`.
- Schedules: `Services/ScheduleExtractor.swift` and `ViewModels/BatchScanViewModel.swift`.

## Rules
- Harden and extend the existing code. Don't add a parallel system.
- On a conflict, flag the overlap and let the user choose: save anyway, edit the time, or pick another calendar. Only  suggest or apply a different time if the user entered the event manually, because flyer times, syllabi, etc. are set by the organizer.
- Batches never drop an item silently. Every skipped, merged, or deduped item stays visible with its reason.
- Archive-wide duplicate clusters and schedule import are Premium (`PremiumFeature.duplicateClusters`, `.scheduleImport`). Keep the controls visible and open the paywall on tap. Never compute and show paid results to free users.
- Cover these edge cases with tests: all-day vs timed events, cross-midnight shifts, DST and time zones, the same flyer captured in two screenshots, back-to-back events (touching is not overlapping), and the `insufficientGap` threshold.

## Done means
The app target builds with warnings as errors, and the related suites pass (`CalendarServiceTests`, `BatchScanTests`, `ScheduleExtractionTests`, `ScheduleGatingTests`, `AdvisorTests`), run with `-only-testing:PencildTests/<Suite>`.
