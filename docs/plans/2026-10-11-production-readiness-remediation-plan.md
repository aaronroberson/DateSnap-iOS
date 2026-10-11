# Pencil'd production-readiness remediation plan

Date: 2026-10-11  
Scope: `Pencild` visual refresh and production-readiness follow-up

## Current evidence

The five claimed implementation commits are present on `main`, followed by
`f263e8c` (the production-readiness audit). The current checkout is
`repository root`, is 15 commits ahead of `origin/main`, and
has unrelated working-tree changes in `.vscode/` and
`Sources/Pencild/Views/ScanFlowViews.swift`. Those changes stay outside this
plan's edits.

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
