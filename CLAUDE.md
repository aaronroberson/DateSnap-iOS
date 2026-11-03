# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read [`AGENTS.md`](AGENTS.md) too: it covers layout, design-spec rules, and conventions. This file adds commands and architecture. Current identity and StoreKit IDs are listed in [`HANDOFF.md`](HANDOFF.md).

## Commands

```sh
xcodegen generate --spec project.yml          # after adding/removing/moving any source file
xcodebuild -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Single suite / single test (Swift Testing: suite type name, then function name)
xcodebuild test -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PencildTests/ExtractionEvaluationTests/liveRouteReport

python3 scripts/verify-brand-identity.py --worktree   # brand gate (CI + pre-commit)
python3 scripts/tests/test_brand_identity_gate.py
scripts/verify-no-mock.sh                             # mock/placeholder scan against scripts/mock-allowlist.txt
swiftlint                                             # .swiftlint.yml; TODO/FIXME/HACK/XXX in Sources is an error
PENCILD_LIVE_AI_DESTINATION='platform=iOS,id=<udid>' scripts/run-live-ai-evaluation.sh  # real Apple Intelligence on device
```

- The app target builds with `-warnings-as-errors` and complete strict concurrency, so any warning fails the build. The test target relaxes warnings-as-errors only because of a StoreKitTest SDK header.
- Live-model tests are skipped unless `PENCILD_EVAL_LIVE=1`. `PENCILD_REQUIRE_LIVE_AI=1` makes it a failure when the model is unavailable.
- CI (`.github/workflows/ci.yml`) runs the brand gate, then `xcodegen generate`, then the full suite on the first available iPhone simulator. It also warns, without failing, when the committed pbxproj differs from fresh generator output.
- The brand gate rejects the pre-rename app name in new text and filenames.

## Architecture

**Composition root.** `PencildApp` (`Sources/Pencild/Pencild.swift`) builds `ServiceContainer.live()` and sets up the SwiftData container (`UserSettings`, `ScannedAsset`, `EventCandidate`, `SavedEvent`, `InterpretationRecord`, defined in `Persistence/SwiftDataEntities.swift`). Every service sits behind a protocol on `ServiceContainer`, so tests build containers with fakes. Inject the container with `.pencildServices(_:)`, never `.environment(\.services, …)`, because the computed getter traps when it is unset (see the comment in `ServiceContainer.swift`).

**App state.** `AppState` (`Models/AppState.swift`) is the single `ObservableObject` for navigation, holding the selected tab, the `activeModal: AppModalScreen` route, the conflict-resolution context, batch scan sessions, iCloud download confirmations, toasts, and the `EntitlementSnapshot`. Views → ViewModels (`ViewModels/`) → services.

**Scan → review pipeline** (the core of the app; it runs only on device):
1. `OCRService` (Vision), optionally after `ScanImageEnhancer`, produces an `OCRResult`.
2. `EventUnderstandingProviding.analyze` repairs the OCR text (`DateInference.repairOCRText`). It then runs deterministic extraction (`EventExtractionCore.extract`, in `EventExtractionService.swift`, which detects dates and times, splits text into blocks, and dedupes) and `RuleBasedEventAnalyzer`. `IntelligencePolicy.decide` then picks whether to call the on-device model, based on the user toggle, the `DSEnhancedInterpretationRollout` Info.plist flag, capability, and OCR quality. Subscription tier is deliberately not an input.
3. `complete` optionally calls `AppleFoundationModelInterpreter` (FoundationModels, iOS 26+). The call is multimodal with the source image on iOS 27+ and has a timeout. **Every model hypothesis is checked by `EvidenceValidator` against the OCR evidence.** Fields without support are rejected, and if nothing survives, the route falls back to `.rulesOnly`. `InterpretationRanker` merges the baseline, the model output, and deterministic alternatives into a best result, alternatives, and clarifying questions. A visual source assessment can reject non-calendar images outright.
4. The user always reviews before anything is saved (`EventReviewViewModel`). Saving goes through `CalendarService` / `ReminderService` / `NotificationService`, including the conflict preflight. `ScheduleExtractor` splits work schedules and multi-date flyers.

`IntelligenceComposition` chooses the live pipeline per OS/SDK. `EventUnderstandingPipeline.rulesOnly()` is the default for tests, previews, and older OS versions.

**Monetization.** `SubscriptionService` (StoreKit 2) feeds `SubscriptionEntitlementResolver` / `EntitlementCache` / `SubscriptionLease`, which produce the `EntitlementSnapshot`. Free, Plus, and Premium tiers gate only the convenience features listed in `Services/Advisors/FeatureEntitlements.swift` (`PremiumFeature.requiredTier`). Correctness features (scanning, single-scan interpretation, review, save) stay free, with a monthly allowance tracked by `ScanUsageStore`. Paid controls stay visible, and tapping one shows the paywall. Never show results of a paid feature to a user who has not paid. Batches must never skip items silently. Product IDs must match across source, tests, `Pencild.storekit`, and App Store Connect.

**Advisors** (`Services/Advisors/`) are local heuristics for calendar choice, reminder strategy, and duplicate/similarity detection. They are separate from the extraction pipeline.

## Tests

Tests use Swift Testing (`@Test`, `#expect`) in `Tests/PencildTests/`. `ExtractionEvaluationTests` is the fixture-based extraction quality harness. Run it after changing `EventExtractionService`, `RuleBasedEventAnalyzer`, `EvidenceValidator`, or `InterpretationRanker`.

## Docs

Reports and plans go in `docs/audits/`, `docs/plans/`, `docs/runbooks/`, and `docs/business/`, following the user's documentation policy.
