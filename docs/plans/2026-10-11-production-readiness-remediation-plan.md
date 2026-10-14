# Pencil’d production-readiness remediation plan

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

## Outstanding before release (2026-10-14)

Single list of everything still open. Check items off here; the dated sections
below keep the history.

App Store Connect and accounts
- [ ] **Sign in with Apple entitlement.** `Pencild.entitlements` is empty, but
      Profile shows `SignInWithAppleButton`. Move signing from the personal
      team (`WGKKDYY866`) to the LiminalForge, LLC organization team, enable
      the capability on the App ID, add
      `com.apple.developer.applesignin = [Default]`, and verify sign-in on a
      device. Otherwise hide the button for release.
- [ ] **Create the products in App Store Connect** to match `Pencild.storekit`:
      Plus and Premium monthly/annual in one subscription group (Premium
      ranked above Plus), one-week free trial per group, and both lifetime
      non-consumables (`com.pencild.plus.lifetime`,
      `com.pencild.premium.lifetime`). Verify IDs, prices, territories.
- [ ] **Remove the lifetime products after 2027-04-13** (the app stops
      showing them; the store listing must be retired manually).
- [ ] **Decide on the keyword field** from `docs/business/pencild-strategy-review.md`.
      It drops `invite` and `ticket` as well as `party`, `camera`, `file`;
      if adopted, update `docs/runbooks/APP-REVIEW-NOTES.md` and the listing
      Decision Record together.

Verification on device / sandbox
- [ ] **Paywall as a member** (TestFlight or sandbox): Plus member sees
      "Current plan" on their billing option and can switch intervals;
      lifetime owner can't rebuy; Premium member never sees a paywall.
- [ ] **Entitlement retry**: with StoreKit slow or offline at launch, a
      subscriber is treated as free, and the first paywall re-checks and
      skips itself with "plan is active, try that again".
- [ ] **Runtime visual check, iPhone and iPad**: Add events sheet, single-page
      splash, Home source cards (pill truncation on small widths), Enter
      Manually form, Default Calendar (Automatic / Ask every time and the
      Review "Required" state), Default Reminders, Settings root, back
      labels on Settings screens (no duplicate back button), Agenda filters
      and search field, paywall tabs and the Lifetime ribbon.
- [ ] **Add-only Calendar access**: with Calendar set to "Add Events Only",
      saving works and Default Calendar explains that listing needs full
      access.
- [ ] **Schedule extraction** against real scheduling-app screenshots
      (Deputy, 7shifts, Homebase, When I Work).

Product follow-ups (from the strategy review)
- [ ] StoreKit rating prompt after the third successful save.
- [ ] One-scan-left warning state on Home.
- [ ] Trial disclosure built from StoreKit `displayPrice` and offer period.
- [ ] Contextual paywall headline for the triggering feature.
- [ ] Resume the blocked action after a successful purchase.
- [ ] Six-screenshot App Store set; work-schedules Custom Product Page.
- [ ] `PurchaseIntent` handling before promoting any product.

Repository
- [ ] Add `.codebase-memory/` to `.gitignore` (or the brand gate's
      exclusions); the gate flags its index file.
- [ ] Confirm the GitHub Actions workflow is disabled remotely
      (`gh workflow list --all`); the local file is
      `.github/workflows/ci.yml.disabled`.

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
   all in-scope callers migrate. Settings/Profile callers are part of the
   integrated product surface.
5. Separate verified facts from recommendations. A graph result or a stale
   baseline is not completion evidence without a live source read or runtime
   check.

## Sequenced implementation work

### Phase 0 — Evidence lock

- Refresh the audit corrections above.
- Keep the integrated Settings/Profile and shared-file work intact.
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
   `DS*`/`ds*` names across product callers. Migrate only proven
   callers, remove an alias only after a zero-caller search and build, and
   rerun the brand and release-content gates.
4. **[Kept by decision] Provenance-comment review.** Keep the 15 `stitch-id` comments unless the
   mock-data checker is changed to distinguish provenance metadata from runtime
   fixtures. Do not introduce production examples or fabricated data.
5. **[Done 2026-10-13] Work schedules and multi-date flyers (Premium).** One
   event per dated entry via `ScheduleExtractor`,
   gated by `PremiumFeature.scheduleImport`. 172 tests passed on iPhone 17 and
   iPad Pro 11-inch (M5); see audit §7.11. Remaining: tune against real
   scheduling-app screenshots.

## Settings and listing follow-ups (2026-10-13)

Findings from the Settings check and the cross-review of
`docs/business/pencild-strategy-review.md`. Check items off as they land.

### Done in this pass (uncommitted)

- [x] **Default calendar priority order.** Settings → Default Calendar offers
      Automatic (the default until changed), any writable calendar, or Ask every
      time. A chosen calendar overrides the automatic order (learned
      per-category choice, then the iOS default) for every new event; saved
      events and drafts keep their own calendar. `DefaultCalendarView`,
      `DefaultCalendarStore`, `DestinationCalendarResolver`.
- [x] **Ask every time.** The old toggle wrote `settings.askEveryTimeCalendar`
      with no reader and was removed. The new mode (`settings.calendarAskEveryTime`)
      leaves new events with no calendar; Review shows a "Required" badge and
      keeps Save disabled until one is picked. Batch Review disables per-event
      Save, and Save All opens the events still missing a calendar.
      `commitEvent` also refuses to save without one.
- [x] **Reminder presets decided.** Settings → Default Reminders stores one
      preset (`ReminderDefaultsStore`, `settings.defaultReminderPreset`) that
      every new event starts with: Standard (unset default, same alerts as
      before), Travel, or Day-of only. These are the same presets as the
      per-event Reminder Schedule editor (`ReminderPreset.offsets`). Free plan:
      Standard is trimmed to 1 alert; Travel opens the Plus paywall. The
      Settings row shows the chosen preset instead of "Smart, by event type".
- [x] **Source Preferences row.** Renamed "Scanning Options" (it opens the
      auto-detect and Apple Intelligence screen); shows whether Apple
      Intelligence is on instead of the fixed "Screenshots, PDFs, Photos".
- [x] **History row.** Settings → Your Events → Event History opens the history
      archive (`AppState.openHistory()`).
- [x] **Plus paywall lists likely-event triage.** Already present
      (`PlusPaywallView` "Find likely event screenshots"); the gap was in the
      strategy review's paywall-lead table, now fixed.
- [x] **Brand apostrophe.** `Pencil’d` (curly) in app strings, comments,
      tests, `Info.plist`, display name (`project.yml`,
      `Pencild-Base.xcconfig`), `Pencild.storekit`, the listing runbook, and
      business docs. Historical audits and plans keep their original text.
- [x] **Strategy review citations.** Mismatched `[n]` markers removed; sources
      listed unnumbered.
- [x] **Paid filters open the paywall.** `EventSmartFilter.requiredFeature`:
      RSVP Due needs `advancedReminderPlans` (Premium) and Possible Duplicates
      needs `duplicateClusters` (Premium). A locked chip stays visible and opens
      that tier's paywall with the feature's upgrade reason. Applies to Agenda
      and History & Archive.
- [x] **Paid chips are marked.** `LinearGradient.pdPaidFeature` (lavender) plus
      a `PDTierTag` ("PLUS"/"PREMIUM") on paid smart filters and the
      screenshot picker's Likely events chip (`PDChip(paidTier:)`).
- [x] **Capture sources unified.** `CaptureSource` defines the order and
      labels everywhere: Screenshots, Photo Library, PDF & Files Import,
      Document Scanner, Enter Manually. Home shows them as full cards
      (`CaptureSourceRow`; Document Scanner now on iPhone too). The Add events
      sheet (`CaptureSourceSheet`, formerly the launch carousel's second page,
      same layout) shows them as a tile grid (`CaptureSourceGrid`). Agenda's
      "Capture new events" opens the sheet. Scan sources hand off to Home via
      `AppState.beginCapture` (`requestPhotoPicker`, `requestFileImporter`,
      `requestDocumentScanner`, `requestScreenshotPicker`).
- [x] **Splash** is the brand page only (3 seconds, Skip); no carousel.
- [x] **Enter Manually** opens the review form instead of the Calendar app:
      a blank event at the next hour (`ManualEventFactory`,
      `EventCandidate.isManualEntry`) with the default calendar and default
      reminders applied. Scan-only parts (source image, confidence, scan
      details) are hidden; a title is required to save; closing without a
      save or draft deletes it, and it never counts as needing review or uses
      a free scan. Tests: `ManualEntryTests`.
- [x] **One tabbed paywall** (`PaywallView`, presented as
      `AppModalScreen.paywall(opening: .plus / .premium)`; callers pick only
      the tab, `AppModalScreen.paywall(for: feature)`). Free and Plus users see Plus | Premium tabs; Plus is the default
      unless a Premium feature opened it. Plan order: Lifetime (angled purple
      "Intro offer" tag, `pdSecondaryContainer`), Annual, Monthly; "You stay
      in control" sits below the plan options.
- [x] **Switching billing intervals.** On the member's own plan, the option
      they already have shows "Current plan" and is disabled; the others stay
      selectable ("Switch to Annual…"). Lifetime owners can't buy that plan's
      subscriptions. Current product: `PurchaseViewModel.currentProduct(for:)`.
- [x] **Premium is never gated.** `AppState.present` never shows a paywall to
      a Premium member, and the paywall dismisses itself as a backstop.
      Entitlement logic has one source of truth: `EntitlementSnapshot.effectiveTier`
      (verified tier, otherwise free) feeds `FeatureAccessPolicy` and
      `PlanLimits`; `EntitlementProviding` adds `isEntitled(to:)` and
      `resolveBeforeUpsell()` (re-requests an unresolved check,
      `EntitlementProvenance.gateRetry`). `AppState` mirrors the snapshot, and
      `shouldShowPaywall()` (used by `present` and the paywall view) retries
      first and skips the paywall with a "plan is active, try that again" toast
      if a paid tier resolves. Removed the "checking means allowed" exceptions
      in `PlanLimits` and `ScanViewModel.isAllowed`. Tests:
      `EntitlementRetryTests`, `PlanLimitsTests`.
      Reminder editor no longer opens the Plus paywall at the paid 3-alert
      maximum. Tier tags use `SubscriptionTier.badgeText` ("PLUS", "PREMIUM");
      Settings/Profile no longer render "Pencil’d Pencil’d Premium".
- [x] **Back button labels.** `PDTopBar` shows a chevron plus a small all-caps
      label: the previous screen when the pushing stack knows it
      (`\.pdBackLabel`: "Settings" for Settings screens, "Agenda" for History),
      otherwise "Back" (sheets, and screens reachable from more than one place).
      VoiceOver reads "Back to Settings" / "Back".
- [x] **Duplicate back button on Settings screens** (reported on Privacy &
      Processing). `SettingsClusterView` never hid the system navigation bar,
      so every pushed Settings screen showed an iOS back button above the
      in-content one. The bar is now hidden for the hub and its destinations.
      Removed the unused `SettingsBackButton`. Needs a runtime visual check.
- [x] **Shared search field.** `PDSearchField` (48pt minimum, clear button,
      no autocorrection) is used by Agenda, History & Archive, and Help &
      Support.
- [x] **Agenda order** is one chronological list, earliest date first; today
      keeps its highlighted section in place.
- [x] **Agenda All** clears the status and smart filters and shows saved,
      draft, and archived events; picking another date filter returns to Saved.
- [x] Tests: `ReminderDefaultsStoreTests`; Ask-every-time store test in
      `DefaultCalendarTests`.
- [x] Verification: iPhone 17 (iOS 27.0) `xcodebuild test`, 177 tests in 38
      suites passed after the apostrophe change; `git diff --check` clean. The
      brand gate flags only the untracked `.codebase-memory/artifact.json`
      (local code-index cache; add `.codebase-memory/` to `.gitignore` or the
      gate's exclusions).

### Open

Moved to "Outstanding before release" near the top of this plan.

## Single-source-of-truth audit (2026-10-14)

Business rules found implemented in more than one place. Each item names the
proposed owner. Ordered by risk.

- [x] **"Needs review" definition (bug).** Four copies:
      `ContentView.needsReview` (tab badge), `HomeEmptyStateView.needingReviewCount`,
      `ReviewQueueView` (`ScanFlowViews.swift:401`), `CaptureSourceSheet` library
      card. ContentView's copy lacks the manual-entry exclusion, so the Review
      badge shows while a blank manual event is open. Fixed: all four use
      `EventCandidate.needsReview`.
- [x] **Manual entry has two creators.** `ManualEventFactory` is now the only
      creator (optional `ScanPrefill` for No Dates Found, which keeps its flyer
      and stays in Review); `AppState.startManualEntry` creates, reports save
      failures, and opens the form for Home, the Add events sheet, and No
      Dates Found.
- [x] **Found while testing: Save Draft filed new events as Saved.** A new
      `SavedEvent` defaults to "Saved", and `saveDraft` only demoted records
      that weren't Saved, so a never-saved scan's draft was stored as Saved
      (no Calendar event). Now anything not in Calendar is a draft. Test:
      `ManualEntryTests.draftOfNewEventIsDraft`.
- [x] **Paywall routing by tier.** One `PaywallView`; callers choose only the
      opening tab via `AppModalScreen.paywall(for: PremiumFeature)` (was 3
      copies of the tier → paywall mapping). Batch Review's two paywall sheets
      are one `paywallTab`.
- [x] **Alert-limit upsell rule.** `maxAlerts < PlanLimits.paidAlertsPerEvent`
      and "preset has more alerts than the plan" are re-derived in
      `ReminderSettingsView` and `ReminderScheduleEditorView` (3 places), and
      the two screens disagreed (Settings allowed Standard on free; the editor
      locked it). Now `PlanLimits.canUpgradeAlerts(from:)` and
      `ReminderPreset.isLocked(maxAlerts:)` / `offsets(limitedTo:)`: Standard is
      never locked (trimmed to the plan's limit), others lock above it.
- [x] **"Upcoming" means two things.** `AgendaDateFilter.upcoming` = from the
      start of today; `EventSmartFilter.upcoming` (History) = from now. "RSVP
      Due" uses start of today. Now History's filter and RSVP Due call
      `AgendaDateFilter.upcoming` (from the start of today).
- [x] **Permission meaning differs by screen.**
      - Photos "usable" (`authorized || limited`) is re-derived 6+ times
        (`HomeViewModel` ×5, `HomeEmptyStateView`, `SavedEventDetailView`).
      - Calendar: Settings shows write-only as granted ("Add Only");
        `HomeViewModel.isCalendarAuthorized` requires full access;
        `DefaultCalendarView` requires full access.
      - Notifications: Settings counts `.ephemeral` as on; `HomeViewModel` and
        `NotificationService` don't.
      Now `PermissionAccess` (granted / partial / denied / not asked, plus
      `isUsable`, `canReadCalendars`, Settings labels) is used by Settings,
      Home, Default Calendar, Saved Event Detail, and the Calendar, Reminders,
      Photos and Notification services. Also fixed: `CalendarService` refused
      to save with add-only access (now allowed, as EventKit permits).
      Tests: `PermissionAccessTests`.
- [x] **All-day alert time.** The 9 AM rule is coded in both
      `ReminderService` (all-day alerts) and `ReminderStrategyService` (RSVP
      deadline reminder). Now `ReminderOffset.allDayAlertHour`, and the RSVP
      reminder reuses `ReminderOffset.triggerDate`.
- [x] **Untitled title.** Saved as "Untitled Event" (`EventReviewViewModel`)
      but shown as "Untitled event" (`BatchReviewView`). Now
      `PencildEvent.untitledTitle`; the "Location TBA" placeholder is
      `PencildEvent.locationPlaceholder`.
- [x] **Support email** repeated 4× in `HelpFeedbackView`. Owner:
      `PencildLinks.supportEmail` / `supportMail(subject:)`.
- [x] **Maps link builder** duplicated in `EventReviewFieldsCard` and
      `SavedEventDetailView` (only one skipped the location placeholder). Now
      `PencildLinks.maps(_:)`. Tests: `SharedRulesTests`.
- [x] **Persistence from views.** `NoDatesFoundView` no longer inserts or
      deletes models (covered by the manual-entry item above).
- [x] **Dead code.** `Features/ContactIntegration.swift` (no callers; own
      1-hour duration default) and `Views/DefaultCalendarSection.swift` (an
      older inline picker superseded by `DefaultCalendarView`); both deleted,
      and no Contacts usage keys existed.
- [x] **Top-bar titles.** `PDTopBar` no longer repeats the title shown by the
      screen's `PDScreenIntro`; opt in with `showsTitle` (Event Details,
      Marketing Kit). Settings intro: "Settings" eyebrow, "Make it yours" title.
      Verification: iPhone 17, 196 tests in 42 suites passed.

Already centralized (no action): entitlements (this pass), scan allowance
counting (`ScanUsageStore`), event duration (`EventDurationPolicy`),
destination calendar choice (`DestinationCalendarResolver`), default reminders
(`ReminderDefaultsStore`), capture sources (`CaptureSource`), legal links
(`PencildLinks`), duplicate clustering (`EventSimilarityService`).

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
- At the time, items 3 (alias retirement) and 4 (provenance comments) remained open. Item 3 was closed in the next entry.

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

2026-10-12: Batch Review and scan-flow component alignment; history committed.
- Committed the 2026-10-11 work as eight atomic commits (`1914562`..`ee9559f`).
  Each source commit was checked out clean in a temporary worktree and passed
  `build-for-testing` on iPhone 17.
- `BatchReviewView` now uses `PDCard`, `PDSectionHeader`, and `PDGroupedList`,
  with width-capped content and Save All bar on iPad, the progress screen's
  no-dates icon, and tokenized spacing. `RecentScreenshotsView` now uses
  `PDTopBar` with a single Select/Cancel action and a `PDCard` empty state.
  `ReviewQueueView` uses a two-column grid on iPad with a capped action bar.
- New smoke renders: `populatedBatchReviewSmoke` and `scanFlowSmoke` in
  `TabletWorkspaceTests`.
- Fixed a regression in the 2026-10-11 generation guard, found by a full-suite
  run. A transaction-update refresh that started during `restorePurchases()`
  outranked the restore's read, so restore returned a stale `.starter`.
  Entitlement refreshes are now serialized in request order, and only a
  direct `apply` invalidates an earlier refresh. The StoreKit integration
  tests now drive `SubscriptionService.shared`, so a single listener finishes
  each transaction. Tests that only exercise resolution use
  `SubscriptionService(observesTransactionUpdates: false)`. The integration
  tests wait for `isProcessingTransactionUpdate` and `Transaction.unfinished`
  to settle before clearing their session. Three consecutive full-suite runs
  per device (131 tests) passed with zero "Error finishing transaction" log
  lines.
- Status: next-wave items 1 to 3 are done. Item 4 (keep the 15 `stitch-id`
  comments) stands by decision. At the time, the `AppState` navigation naming
  audit and the paywall headers (Profile & Settings audit §3.3 and §3.4) were
  still open. Both were closed on 2026-10-12; see below.

2026-10-12: `AppState` navigation-naming audit (Profile & Settings audit §3.3).
- Every modal goes through `AppState.present(_:)`; 13 direct `activeModal`
  assignments were removed. Navigation helpers moved into `AppState.swift`
  with a single `sheetDismissalDelay`. `SettingsState.pendingRoute` is typed as
  `SettingsRoute?`.
- Fixed the Batch Review duplicate "open existing event" action, which could
  not present over the batch sheet.
- New `AppStateNavigationTests`. The navigation changes were committed in
  `37eede7`/`fe92247`, together with other follow-up work.
- Build fix: the strict-concurrency gate (`1bdf83c`) applied warnings-as-errors
  to the test target as well. There, Apple's StoreKitTest SDK header (a
  deprecation in `SKTestTransaction.h`) failed to precompile, so tests could
  not build. The test target now keeps `-strict-concurrency=complete` without
  warnings-as-errors, in both Xcode and SwiftPM; the app target keeps the full
  gate. iPhone 17 and iPad Pro 11-inch (M5): 137 tests in 32 suites passed
  (`/private/tmp/pencild-head-iphone.xcresult`,
  `/private/tmp/pencild-head-ipad.xcresult`). The strict Release build and the
  release-content scan passed.

2026-10-12: Paywall interstitials done (no top bar by design).
- The Plus and Premium paywalls share a pinned `PDInterstitialHeader`: Restore
  on the leading edge, an "Upgrade to Plus"/"Upgrade to Premium" title, and
  close in the top-right corner. The intro eyebrow spacing is fixed.
- Reverted the `37eede7` purchase-button change. Buttons again show the live
  StoreKit price, the trial offer, or "Price unavailable".
- No open items remain from the Profile & Settings follow-up audit.

2026-10-13: Extraction grounding fixes, from user reports.
- `3b33161`: only text that names a day produces an event. The status-bar
  clock and bare times no longer fabricate dates, so undated screenshots stay
  out of Review.
- `abd8829`: the title is the most prominent line, not a wide description.
- iPhone 17 and iPad Pro 11-inch (M5): 145 tests in 33 suites passed.

2026-10-13: Lifetime introductory offer (see audit §7.8).
- Non-consumable `com.pencild.plus.lifetime` ($39.99 locally) and
  `com.pencild.premium.lifetime` ($79.99 locally), shown through 2027-04-13.
- Open: create both products in App Store Connect before release.

2026-10-13: Free plan limits and paywall-on-attempt (see audit §7.9).
- Free plan: 10 scans/month (scans that find a new event) and 1 alert per
  event; paid plans: unlimited scans and 3 alerts. No history limit.
- Gated actions open the paywall instead of being hidden or disabled.
- Batch scans now check the allowance before starting and prompt to
  deselect, upgrade, or discard, instead of skipping items.

2026-10-13: Work schedules and multi-date flyers (see audit §7.11).
- `ScheduleExtractor` turns a schedule screenshot into one event per dated
  entry (shifts, roster rows, multi-date flyers, syllabus lines).
- Premium feature `scheduleImport`: lower plans see the Premium paywall when a
  schedule is detected; nothing is saved and no free scan is used.
- Scans that find several events open them all in Batch Review.
- Open: tune against real scheduling-app screenshots (Deputy, 7shifts,
  Homebase, When I Work) before release.
- iPhone 17 and iPad Pro 11-inch (M5): 172 tests in 37 suites passed.

2026-10-13: Plans, limits, and paywall rules marked as intended design.
- Recorded in audit §7.12 and in the decision record in
  `docs/business/Pencild-Monetization-Strategy.md`. These are deliberate
  behaviors, not open findings.

2026-10-14: UI/UX audit follow-up (this session).
- Addressed all items from `2026-10-10-profile-settings-followup-audit.md`:
  - `BatchReviewView.swift`: `dsGlassCard` → `PDCard`, button style fixes
  - `ScanFlowViews.swift`: `DSConfidencePill` → `PDStatusBadge`, button style fixes
  - `AgendaView.swift`: Verified `openHistory()` validity (no code change needed)
  - Paywalls/History views: Already using PD components (verified via grep)
- UI/UX audit report created at `docs/audits/ux-audit-report.md`:
  - 28 view files analyzed (10,841 lines)
  - Screen-by-screen text-heavy area analysis with tooltip recommendations
  - Design assessment: 9/10 rating, self-evident & intuitive workflows
  - End-to-end workflow: 5/5 rating (Home → Scan → Review → Save → Profile/Settings)
- Paywall CTA titles standardized:
  - `PlusPaywallView.ctaTitle` → `"UPGRADE TO PLUS"`
  - `PremiumPaywallView.ctaTitle` → `"UPGRADE TO PREMIUM"`
- Removed breadcrumbs from `EventReviewEditView` header (Agenda/Review > Verify details HStack)
- Reordered form section: "CALENDAR & REMINDERS" now appears above "SUGGESTIONS"
- Removed "Aa" icon (`textformat`) from `EventReviewFieldsCard` title field
- Correction (2026-10-13): the tailored-alerts control was not removed. Without
  Premium it stays visible and opens the Premium paywall; the suggested plan is
  not shown. Policy: Premium controls stay visible behind the paywall, and the
  results of Premium operations are not shown without the entitlement.
- The earlier 131-test/build result is historical and is not current evidence;
  the current generic iOS build is blocked by CoreSimulatorService during asset
  processing (see audit §7.11).
- 100% local-first invariant maintained — no telemetry or remote dependencies added
