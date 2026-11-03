# AGENTS.md

## What this is

Pencil'd is a SwiftUI iOS application. The Xcode project is generated from [`project.yml`](project.yml); `Package.swift` also exposes the same app and test sources to SwiftPM/Xcode. Do not hand-edit generated project references as a substitute for updating the XcodeGen spec.

## Layout

- [`Sources/Pencild/`](Sources/Pencild/) — app entry point, models, persistence, services, view models, themes, and SwiftUI views.
- [`Tests/PencildTests/`](Tests/PencildTests/) — Swift Testing unit tests.
- [`Pencild.xcodeproj/`](Pencild.xcodeproj/) — generated Xcode project and shared `Pencild` scheme.
- [`Config/`](Config/) — Pencild Debug, Release, and base xcconfigs.
- [`Assets.xcassets/`](Assets.xcassets/) — app icon catalog and other assets; `Pencild.icon/` is the Icon Composer source.
- [`Pencild.storekit`](Pencild.storekit) — local StoreKit test catalog; live App Store Connect parity is not implied.
- [`pencild-design-system-updated.md`](pencild-design-system-updated.md) — design spec. Read before writing or changing UI; map its CSS token names to SwiftUI equivalents.
- `lancedb/` — local vector-store runtime data. Do not commit, delete, or rewrite it as part of ordinary source changes.

## Build, test, and commit checks

Install the repository's staged-file pre-commit brand check once per clone:

```sh
./scripts/install-hooks.sh
```

GitHub Actions is intentionally disabled on this repository (owner decision, 2026-11-03: Actions usage budget/limits are exhausted), so `.github/workflows/ci.yml` will not run. Local checks are authoritative: run the brand gate and the scripted regression suite yourself before pushing (`./scripts/install-hooks.sh` sets up the pre-commit gate), and run the xcodebuild commands below for anything affecting Swift sources. Do not re-enable Actions, and do not delete or rename `ci.yml`.

```sh
xcodegen generate --spec project.yml
xcodebuild -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Use an available simulator destination from `xcrun simctl list devices available` if iPhone 17 is not installed. The app uses iOS-only APIs; prefer an iOS Simulator build/test over a macOS `swift build`.

## Language and design conventions

- Swift 6.4 tools, Swift 6 language settings, with `ApproachableConcurrency` enabled. Keep new code concurrency-safe.
- SwiftUI-first; no external Swift package dependencies are currently declared.
- Follow the design spec and existing component patterns. Preserve accessibility: at least 44pt touch targets; confidence states combine icon, label, and color.
- Preserve the current local-first processing and explicit review-before-save behavior. Do not add remote services, analytics, or account integrations without a separate approved task.
- Keep app, StoreKit, notification, and persistence identifiers coordinated across source, tests, `Pencild.storekit`, and project configuration.


## Specialized Jules Subagents

When assigning or handing off scoped tasks to Jules agents, ground prompts according to these role specializations and standards:

### 1. Duration Advisor (`pencild-duration-advisor`)
- **Domain:** Category-based suggested durations and end-time defaults when flyers lack an explicit end time.
- **Code Seams:** `Sources/Pencild/Services/Intelligence/EventDurationPolicy.swift` (`suggestedDuration(for:)`, `fallbackEnd(for:)`), `Sources/Pencild/Services/Intelligence/EventUnderstandingModels.swift` (`EventCategory`, `DurationSource`).
- **Tests:** `Tests/PencildTests/EventUnderstandingTests.swift`, `Tests/PencildTests/ExtractionEvaluationTests.swift`.
- **Invariants:** Explicit end times on flyers always take precedence over heuristics. Suggested durations are user-editable review defaults (never silently saved). Appointments are 1h (3600s), and `.deadline`/`.other` strictly return `nil`. (A dedicated dining duration (~1.5h) exists only as a proposal in plan docs; it is not yet implemented in `EventDurationPolicy`.)

### 2. Conflict & Multi-Event Triage (`pencild-conflict-triage`)
- **Domain:** Calendar overlap detection, save-time and batch conflict preflight, duplicate flyer clustering, and multi-date / multi-shift schedule splitting.
- **Code Seams:** `Sources/Pencild/Services/CalendarService.swift` (save-time preflight), `Sources/Pencild/Services/Intelligence/EventDurationPolicy.swift` (`ScheduleConflictAnalyzer`, `ScheduleInterval`), `Sources/Pencild/Services/Advisors/EventSimilarityService.swift` (`matches`, `clusters`), `Sources/Pencild/Services/ScheduleExtractor.swift` (`extract`).
- **Tests:** `Tests/PencildTests/CalendarServiceTests.swift`, `Tests/PencildTests/BatchScanTests.swift`, `Tests/PencildTests/ScheduleExtractionTests.swift`.
- **Invariants:** Scanned events flag conflicts for user choice (save anyway / edit time / change calendar) without suggesting artificial times; manual entries offer alternative open slots. Batches never drop items silently.

### 3. Action Grounding (`pencild-action-grounding`)
- **Domain:** Action suggestions attached to extracted events (Apple Maps URL, ticket/RSVP URLs, video-meeting links, tel/mailto).
- **Code Seams:** `Sources/Pencild/Views/InterpretationReviewViews.swift` (`validatedActionURL`), `Sources/Pencild/Services/Intelligence/EvidenceValidator.swift`, `Sources/Pencild/Services/NotificationService.swift`.
- **Tests:** `Tests/PencildTests/EvidenceValidationTests.swift`, `Tests/PencildTests/ScreenshotGroundingTests.swift`.
- **Invariants:** Strictly verbatim OCR evidence grounding. Zero hallucinated actions. No Contacts framework, no in-app network lookups (`MKLocalSearch`), and negative tests for missing evidence.

### 4. Paywall & Value Proposition (`pencild-paywall-advisor`)
- **Domain:** Contextual upsell copy and paywall value statements when paid features are tapped.
- **Code Seams:** `Sources/Pencild/Services/Advisors/FeatureEntitlements.swift` (`PremiumFeature` values, `LifetimeIntroOffer`), `Sources/Pencild/Views/PaywallView.swift`, and inline gates across scan/batch/reminder views.
- **Tests:** `Tests/PencildTests/EntitlementPolicyTests.swift`, `Tests/PencildTests/PurchaseViewModelTests.swift`.
- **Invariants:** Static localizable copy only (never runtime or AI-generated). No countdown urgency or guilt. Paid controls stay visible and open paywall on tap; free users are never shown paid feature results. Prices injected live from StoreKit `Product.displayPrice`.

## Prompt Grounding Standards for Agent Handoffs
Every task prompt handed off to a Jules agent must provide:
1. **Concrete Objective:** Specific problem statement and background rationale.
2. **Exact Files, Methods, and Line Numbers:** Grounded file paths with exact symbols and current line numbers.
3. **Expected Concrete Outcomes:** Explicit return types, error handling, and behavioral invariants.
4. **Repository & Safety Conventions:** Swift 6 strict concurrency (`Sendable`-correct), warnings as errors, no `print` (use `os.Logger`), no force-unwraps (`!`), no `TODO`/`FIXME` markers in `Sources/`, no direct `Pencild.xcodeproj` edits, and brand compliance (`Pencil'd` / `Pencild`).
5. **Verification Requirements:** Explicit Swift Testing assertions and execution commands.
