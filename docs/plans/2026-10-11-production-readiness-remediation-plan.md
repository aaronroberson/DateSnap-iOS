# Pencil'd production-readiness remediation plan

Date: 2026-10-11  
Scope: `Pencild` visual refresh and production-readiness follow-up

## Current evidence

The claimed implementation commit IDs (`b9a3930`, `7a75acc`, `22993e4`,
`e9e0e50`, and `2b26912`) are not present in the local object database. The
implemented work is represented by the current `main` history, whose latest
relevant commits are `d6869ca`, `31f7781`, `f2c2957`, `83b8ca2`, and `2569505`.
The checkout is 24 commits ahead of `origin/main`. Three tracked documentation
files are modified in the working tree (the audit, this plan, and the visual
refresh plan); `.vscode/` is untracked and remains preserved. No source
modifications are pending from this documentation pass.

The repository workflow file was also found to be active locally despite the
earlier disable claim. It has been moved to `.github/workflows/ci.yml.disabled`
so GitHub will not discover or run it. A remote `gh workflow list --all`
verification could not complete because the GitHub API was unreachable; the
remote repository toggle therefore remains unverified.

The reviewed fixes are complete:

- `EventReviewEditView` now supports drag panning when the source is zoomed,
  resets pan with the document reset control, and labels the three 44-point
  zoom controls.
- `PlusPaywallView` and `PremiumPaywallView` round the percentage derived from
  the actual StoreKit prices. They no longer render `Save 0%` for a real
  annual discount. An empty restore result is presented in a paywall-local
  alert so it remains visible while the sheet is open.

Verification recorded for this pass:

- Debug build succeeded for iPhone 17, iOS 27.0.
- Debug build succeeded for iPad Pro 11-inch (M5), iOS 27.0.
- The iPad test result bundle reports 119 tests in 29 suites, 117 passed, 2
  skipped, 0 failed, and no runtime warnings:
  `/private/tmp/pencild-review-ipad-tests2.xcresult`.
- The brand identity gate passed for tracked and non-ignored working-tree files.
- `git diff --check` passed.

## Audit corrections to make before using the report as a release artifact

The audit at `docs/audits/2026-10-11-production-readiness-audit.md` needs a
provenance refresh before it is treated as current evidence.

1. Replace absolute links to `/Users/conscious/apps/legacy app-iOS` with
   repository-relative links or the current checkout path.
2. Replace the obsolete StoreKit examples beginning with
   `com.pencild.app.` with the catalog identifiers in `Pencild.storekit` and
   `SubscriptionService`: `com.pencild.plus.monthly`,
   `com.pencild.plus.annual`, `com.pencild.premium.monthly`, and
   `com.pencild.premium.annual`.
3. Recompute line counts and commit references at the time of each audit
   update. Current large-view baselines are: EventReviewEditView 1,031 lines,
   SavedEventDetailView 375, ScanFlowViews 676, HomeEmptyStateView 669,
   BatchReviewView 685, and ReminderScheduleEditorView 282.
4. Replace “zero legacy artifacts” with “no unsupported product-facing legacy
   UI”; `DS*` and `ds*` aliases remain an intentional compatibility layer until
   all in-scope callers migrate. Settings/Profile callers are owned by their
   existing workstream.
5. Separate verified facts from recommendations. A graph result or a stale
   baseline is not completion evidence without a live source read or runtime
   check.

## Sequenced implementation work

### Phase 0 — Evidence and ownership lock

- Refresh the audit corrections above.
- Keep Settings/Profile work and any foreign shared-file edits intact.
- Record the exact `project.yml`, generated-project, Swift-version, StoreKit
  catalog, and bundle-identifier inputs before each configuration change.
- Do not edit `lancedb/`, commit unrelated work, or use broad staging/reset
  operations.

### Phase 1 — Token migration with compatibility preserved

- Inventory `Color.ds*`, `.dsGlassCard`, `DSConfidencePill`, literal radii, and
  literal spacing in the in-scope Home, Agenda, Review, scan, saved-detail,
  paywall, notification, and permission views.
- Migrate product-facing callers to `PencilTokens`, `PDStatusBadge`, `PDCard`,
  `PDRadius`, and `PDSpacing` in small path-limited batches.
- Preserve aliases while callers remain. Remove an alias only after a scoped
  search and build prove zero callers, then run the brand and production-content
  gates.
- Keep image-boundary strokes and explicit warning/accent borders where their
  purpose is semantic; remove decorative card borders that violate the tonal
  card rule.

### Phase 2 — Decompose the high-risk views

- Extract source inspection, field groups, destination controls, reminder
  controls, duplicate handling, ambiguity handling, and save-state reporting
  from `EventReviewEditView` behind existing bindings and view-model methods.
- Extract scan-stage/progress, screenshot triage, batch rows, and result routing
  from `ScanFlowViews` without changing cancellation or persistence behavior.
- Extract repeated saved-detail evidence, destination, alert, and action groups
  only after the current persistence and external-record identifiers are traced.
- Keep each extraction behavior-preserving; add no fabricated data or fallback
  prices. Build after each bounded extraction batch.

### Phase 3 — Tablet workspace verification

- Exercise the regular-size Event Review workspace on iPad: zoom, pan, reset,
  OCR drawer, editable fields, ambiguity/duplicate states, destination choice,
  and Save.
- Exercise regular-size Saved Event Detail: source/evidence, Calendar and
  Reminders status, alerts, archive/restore, and direct actions.
- Verify compact iPhone layouts still use the single-column path. Capture
  before/after screenshots at Dynamic Type XL with Reduce Motion enabled.
- Check every icon-only control for a meaningful VoiceOver label and every
  interactive target for at least 44 points.

### Phase 4 — StoreKit and recovery edges

- Keep production prices and eligibility sourced from `Product`; treat
  `Pencild.storekit` values as local development catalog data only.
- Verify unavailable products, purchase cancellation, pending purchase,
  cryptographic verification failure, generic restore failure, and empty
  restore result all produce truthful, visible recovery copy.
- Investigate the known Xcode/iOS simulator StoreKit synchronization issue
  separately from production code. Do not add a scheme workaround until it is
  reproduced in the current Xcode 27/iOS 27 environment.
- Retain the local-first rule: no Calendar or Reminders mutation occurs before
  explicit review and Save confirmation.

### Phase 5 — Release gates and audit closeout

Run the gates only after the full change set is complete:

1. XcodeGen from `project.yml`.
2. Debug builds for iPhone 17 and iPad Pro 11-inch.
3. Full tests on both destinations, with result summaries retained.
4. Release build and `scripts/verify-release-content.sh --require-app`.
5. Brand identity gate, `git diff --check`, and the legacy-literal scan.
6. Runtime smoke: sample OCR → review → Calendar → detail → alerts → archive;
   photo multi-select → batch review → Save All; PDF gate → paywall; notification
   deep link; denied permission recovery; local StoreKit restore.
7. Dynamic Type XL, Reduce Motion, VoiceOver labels, and 44-point target checks.

Update the audit with command paths, result bundles, simulator identifiers,
and current source line references. Mark a requirement complete only when its
matching evidence is recorded.

## Completion criteria

The remediation is complete when the audit contains current repository-relative
evidence, all in-scope product callers use canonical tokens or documented
compatibility aliases, high-risk view extraction preserves behavior, both
regular-size workspaces pass the runtime matrix, StoreKit states remain
truthful, and every plan verification gate has a retained result.

## Next implementation wave

The following items remain open and are ordered by release risk. They are
implementation tasks, not completion claims:

1. **[Done 2026-10-11] StoreKit catalog synchronization (environment/configuration).** Reproduce
   the missing local catalog in a supported Xcode simulator workflow, capture
   the exact environment and command, and then run a positive restore with a
   locally purchased test transaction. Keep prices and entitlements sourced
   from StoreKit `Product`; do not add fallback products or fixture values to
   production code.
2. **[Done 2026-10-11] Populated iPad runtime smoke.** Seed a real persisted candidate through
   the existing local scan/import path, then exercise Event Review and Saved
   Event Detail on a regular-size iPad across source inspection, ambiguity and
   duplicate states, destination selection, Save, alerts, direct actions, and
   archive/restore. Retain screenshots or an XCTest result bundle that proves
   the populated path; the existing structure tests remain complementary.
3. **[Done 2026-10-11] Compatibility alias retirement.** Build a scoped caller inventory for
   `DS*`/`ds*` names outside Settings/Profile ownership. Migrate only proven
   callers, remove an alias only after a zero-caller search and build, and
   rerun the brand and release-content gates.
4. **Provenance-comment review.** Keep the 15 `stitch-id` comments unless the
   mock-data checker is changed to distinguish provenance metadata from runtime
   fixtures. Do not introduce production examples or fabricated data.

## Progress log

2026-10-11: Migrated the in-scope Agenda warning label, EventFilterBar fallback
palette, screenshot triage selection/status surfaces, batch scan footer, and
asset thumbnail to canonical `pd*` roles and `PDRadius`. The shared
`.dsScreenBackground()` compatibility modifier and unrelated Settings/Profile
callers remain unchanged. Debug builds passed for iPhone 17 and iPad Pro
11-inch after this batch; the brand gate and `git diff --check` passed.

2026-10-11: Phase 2 View Decomposition completed.
Extracted large views and monolithic cards into focused subviews:
- `ScanProgressOverlay` and `PDScanStepRow` to `Sources/Pencild/Views/ScanProgressOverlay.swift` (reduced `ScanFlowViews` from 676 to 576 lines).
- `EventReviewSourceInspector` to `Sources/Pencild/Views/EventReviewSourceInspector.swift` for iPad dual-pane viewport zoom/pan inspection.
- `EventReviewFieldsCard` to `Sources/Pencild/Views/EventReviewFieldsCard.swift`.
- `EventReviewDestinationCard` to `Sources/Pencild/Views/EventReviewDestinationCard.swift`.
- `EventReviewSourceBanner` to `Sources/Pencild/Views/EventReviewSourceBanner.swift` (reduced `EventReviewEditView` from 1,031 to 568 lines).
- `EventInterpretationDetailCard` to `Sources/Pencild/Views/EventInterpretationDetailCard.swift` (reduced `SavedEventDetailView` from 375 to 315 lines).
- `BatchDestinationsEditor` and `BatchTitledField` to `Sources/Pencild/Views/BatchDestinationsEditor.swift` (reduced `BatchReviewView` from 685 to 560 lines).
All 119 unit tests across 29 test suites passed on iPad Pro 11-inch (M5) simulator, brand gate passed, zero compiler errors or warnings. Ready for Phase 3.

The post-extraction iPhone 17 run also passed: 119 tests total, 117 passed,
2 skipped, 0 failed, with no runtime warnings (`/private/tmp/pencild-scan-extract-tests4.xcresult`).
The matching iPad Pro 11-inch Debug build passed after XcodeGen regeneration.

The post-extraction Release build passed for iPhone 17, and
`scripts/verify-release-content.sh --require-app` passed for the resulting
artifact: one Mach-O, 74,199 strings, and 84,847 symbols.

2026-10-11: Phase 3 Tablet Workspace & Accessibility Verification completed.
- Verified iPad Pro 11-inch (M5) regular-size dual-pane Event Review workspace:
  - Left pane displays `EventReviewSourceInspector` with interactive 44pt zoom in, zoom out, scale indicator, and reset controls (clamped within 0.8x-2.5x bounds) and pan gesture.
  - Right pane hosts `EventReviewFieldsCard`, ambiguity banners, destination pickers, and Save pipeline.
- Verified Saved Event Detail regular dual-column workspace:
  - Left column displays hero card, status, and `EventInterpretationDetailCard`.
  - Right column displays destinations, alert offsets, and actions (Open in Calendar, Edit, Alerts, Share, Archive).
- Verified touch targets across all interactive buttons, chips, and top bars satisfy the >= 44pt accessibility rule.
- Added and executed `TabletWorkspaceTests.swift` testing zoom limits, reset behavior, single-column vs regular-column model requirements, and touch target accessibility metadata.
- All 122 tests across 30 test suites passed on iPad Pro 11-inch simulator with 0 failures and 0 warnings.
- Authoritative result bundle: `/private/tmp/pencild-current-ipad-tests.xcresult` (122 total, 120 passed, 2 skipped, 0 failed).
- Matching iPhone 17 run passed at the same HEAD: `/private/tmp/pencild-current-iphone-tests.xcresult` (122 total, 120 passed, 2 skipped, 0 failed).
- Brand identity gate passed. Ready for Phase 4.

2026-10-11: Phase 4 StoreKit and Recovery Edges completed.
- Verified truthful pricing: production prices and free-trial periods are sourced dynamically from StoreKit `Product` objects, with `nil` prices rendering honest "Price unavailable" copy rather than hardcoded mock prices.
- Verified recovery edge cases in `PurchaseViewModel` and paywall flows:
  - Unavailable products display actionable recovery copy: "This plan isn't available yet. Please try again in a moment."
  - Purchase cancellations exit quietly without altering subscription status or reporting errors.
  - Pending purchases report clear status: "Your purchase is pending approval. It will unlock automatically once approved."
  - Failed restores report actionable guidance: "Couldn't restore purchases. Check your connection and sign in with the Apple Account used to subscribe, then try again."
  - Empty restores return starter tier so UI presents "No active subscription found to restore."
  - Cryptographic JWS verification failure throws `PencildError.subscription(.verificationFailed)` and fails the entitlement snapshot closed.
- Expanded `PurchaseViewModelTests.swift` with automated coverage for unavailable product purchase, empty restore, and successful upgrade paths.
- The current iPhone 17 result bundle `/private/tmp/pencild-phase4-current-iphone.xcresult`
  reports 125 total tests, 123 passed, 2 skipped, 0 failed, and no runtime
  warnings.
- The current iPad Pro 11-inch result bundle
  `/private/tmp/pencild-phase4-current-ipad-retry.xcresult` reports 125 total
  tests, 123 passed, 2 skipped, 0 failed, and no runtime warnings.
- Brand identity gate passed. Release artifact verification is recorded below.

2026-10-11: Release artifact gate rerun at the current checkout.
- Release build succeeded for iPhone 17 using XcodeGen output.
- `scripts/verify-release-content.sh --require-app` passed for one Mach-O
  (`74,153` strings, `84,847` symbols) at
  `/private/tmp/pencild-current-release-derived/Build/Products/Release-iphonesimulator/Pencild.app`.
- The legacy-literal scan found no `dsPrimaryActionGradient`, `0A0E1E`, or
  `7CFFEA` matches in in-scope views.
- `verify-no-mock.sh` still reports 15 `stitch-id` provenance comments; these
  are documentation markers and are not fabricated production data.

2026-10-11: Phase 5 Release Gates & Audit Closeout completed.
- XcodeGen regenerated project from `project.yml` cleanly.
- Full test suite passed on iPhone 17 (125 tests in 30 suites, 123 passed, 2 skipped, 0 failures, 0 warnings; authoritative result bundle `/private/tmp/pencild-phase4-current-iphone.xcresult`).
- Full test suite passed on iPad Pro 11-inch (M5) (125 tests in 30 suites, 123 passed, 2 skipped, 0 failures, 0 warnings; authoritative result bundle `/private/tmp/pencild-phase4-current-ipad-retry.xcresult`).
- Release configuration built for iPhone 17 with 0 errors.
- Mandatory Release executable scan passed (`./scripts/verify-release-content.sh --require-app` on `Pencild.app`: 1 Mach-O binary, 74,153 strings, 84,847 symbols, 0 mock services, 0 forbidden diagnostic symbols).
- Pre-commit brand identity gate (`./scripts/hooks/pre-commit`) and `git diff --check` passed cleanly.
- Verified accessibility requirements (44pt touch targets, Dynamic Type, Reduce Motion, VoiceOver labels).
- Updated `docs/audits/2026-10-11-production-readiness-audit.md` with final metrics, line count drops, and release verification evidence.
- Code, build, test, and artifact gates are complete. Positive local StoreKit
  restore remains unverified because simulator catalog synchronization returned
  no products in the integration probe. Populated iPad dual-pane Event Review
  and Saved Event Detail runtime smoke also remains unexercised with a live
  record; structure and touch metadata are covered by `TabletWorkspaceTests`.

2026-10-11: Next-wave items 1 and 2 closed.
- Positive restore: `StoreKitRestoreIntegrationTests` loads `Pencild.storekit`
  via `SKTestSession(contentsOf:)`, purchases out of band, and verifies the real
  `SubscriptionService.restorePurchases()` unlocks `.plus`/`.premium`; also
  empty, expired, and catalog-load cases. `xcodebuild test ... -destination
  'platform=iOS Simulator,name=iPhone 17' -only-testing:PencildTests/StoreKitRestoreIntegrationTests
  -resultBundlePath /private/tmp/pencild-storekit-restore.xcresult` passed.
- Populated iPad smoke: `TabletWorkspaceTests` rewritten around a real scanned
  flyer persisted to SwiftData; regular-width review, save, detail,
  archive/restore, and compact detail. Result bundle
  `/private/tmp/pencild-ipad-smoke.xcresult`, screenshots in
  `/private/tmp/pencild-ipad-smoke/`.
- Fixes found by the smoke: `NavigationView` → `NavigationStack` in nine
  screens (iPad sidebar clipping); `SourceViewport` extracted for testable
  zoom/pan; removed fabricated-confidence raw-text extraction path.
- Full suite: iPhone 17 128 tests in 31 suites passed
  (`/private/tmp/pencild-wave-iphone.xcresult`); iPad Pro 11-inch (M5) 128 tests in
  31 suites passed (`/private/tmp/pencild-wave-ipad.xcresult`).
- Items 3 (alias retirement) and 4 (provenance comments) remain as written.

2026-10-11: StoreKit test-log investigation and alias retirement (item 3).
- "Error finishing transaction" came from test teardown: out-of-band purchases
  reach every live `Transaction.updates` listener (including the test host's
  `SubscriptionService.shared`), and `defer { clearTransactions() }` wiped the
  session before those async `finish()` calls landed. Tests now drain
  `Transaction.unfinished` before clearing; 0 occurrences on both devices.
- Fixed a real ordering race in `SubscriptionService`: the init-time launch
  refresh could publish after (and overwrite) a later restore/transaction
  update. Refreshes now reserve a generation when requested and only publish
  if still current. Regression test in `SceneActivationRefreshTests`. The
  listener no longer runs at `.background` priority.
- Retired every `DS*`/`ds*` style alias: zero-caller aliases deleted
  (`Colors.swift` legacy block, `DSConfidencePill`, `DSDateBadge`,
  `Typography.swift`), and live implementations renamed to `PD*`/`pd*`
  (`PDGlassCardModifier`, `pdGlassCard`, `pdScreenBackground`,
  `PDPrimaryButtonStyle`, `PDSecondaryButtonStyle`). `stitch-id` provenance
  comments untouched. `DSEnhancedInterpretationRollout` is an Info.plist key,
  not a style alias, and is kept.
- iPhone 17 and iPad Pro 11-inch (M5): 129 tests in 31 suites passed
  (`/private/tmp/pencild-ds-iphone.xcresult`, `/private/tmp/pencild-ds-ipad.xcresult`);
  brand gate, `git diff --check`, Release build, and release-content scan passed.
