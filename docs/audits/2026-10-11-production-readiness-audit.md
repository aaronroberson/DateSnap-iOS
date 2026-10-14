# Pencil'd Production Readiness & Codebase Architecture Audit

**Date:** 2026-10-11  
**Scope:** Architecture, Design System Conformance, Rebranding Integrity, API Feasibility, Component Reusability, and Decomposition Targets  
**Target Platform:** iOS 17.0+ (SwiftUI, Swift 6 Approachable Concurrency, XcodeGen)

> **Evidence correction (2026-10-11):** This report was refreshed against the current repository checkout (`repository root`). Its canonical StoreKit catalog identifiers are `com.pencild.plus.monthly`, `com.pencild.plus.annual`, `com.pencild.premium.monthly`, and `com.pencild.premium.annual`. The `DS*` and `ds*` names mentioned below are intentional internal compatibility aliases, not product-facing legacy branding. Current baselines and a correction sequence are recorded in [`docs/plans/2026-10-11-production-readiness-remediation-plan.md`](../plans/2026-10-11-production-readiness-remediation-plan.md).

The five commit IDs supplied in the handoff (`b9a3930`, `7a75acc`,
`22993e4`, `e9e0e50`, and `2b26912`) are not present in the local Git object
database. This audit therefore cites the live checkout and its verified
artifacts rather than treating those IDs as repository evidence. The automatic
GitHub Actions workflow is disabled in this checkout by moving it to
`.github/workflows/ci.yml.disabled`; remote workflow state could not be checked
because the GitHub API was unreachable.

---

## 1. Executive Summary

This audit assesses the Pencil'd codebase across seven key dimensions:
1. **Stitch Design Feasibility & API Boundaries** (documenting features in Stitch mockups that cannot or should not be implemented due to iOS sandbox, hardware, or privacy constraints).
2. **Rebranding Migration Integrity** (verifying that there is no unsupported product-facing legacy UI).
3. **Design System & Token Conformance** (measuring adherence to Luminous Precision tokens vs. remaining legacy `DS*` aliases and hard-coded values).
4. **Component Consistency & Reusability** (shared component adoption vs. ad-hoc reimplementations).
5. **Overly Long / Monolithic View Decomposition** (identifying complex views that exceed 400+ lines and require modular refactoring).
6. **Best Practices, Concurrency, and Crash Safety** (Swift 6 strict concurrency, forced unwraps, `preconditionFailure` audit, and memory/performance considerations).
7. **Actionable Remediation Roadmap** for engineering teams picking up subsequent implementation waves.

---

## 2. Stitch Design Feasibility & Platform API Boundaries

During analysis and implementation of the Stitch design screens (specifically `.stitch/.../IPad-Verification-Workspace` and related desktop/tablet canvases), several UI elements and interactions were identified that **cannot or should not be implemented as depicted** due to iOS SDK constraints, sandbox policies, or core architectural commitments:

| Design Element in Stitch | Mockup Location | Platform / API Limitation | Engineering Resolution |
| :--- | :--- | :--- | :--- |
| **External SMS Alerts** | `IPad-Verification-Workspace` §5 ("Automated Alerts") | iOS applications have no private background SMS daemon or carrier SMS API without an external cloud backend (e.g., Twilio), user sign-in, and cellular transmission fees. | Rely exclusively on local `EventKit` calendar alarms and `UserNotifications` (`UNNotificationRequest`). Zero external telephony required. |
| **Live Transit Duration Calculations** | `IPad-Verification-Workspace` Venue card (`"22 min transit from Home"`) | Requires constant `CoreLocation` background tracking of the user's home address, geocoding, and continuous `MKDirections` network calls. Violates the zero-cloud-leak guarantee and triggers intrusive location permission dialogs. | Provide direct, privacy-preserving Apple Maps deep links (`maps.apple.com/?q=...`) on tap, without background tracking. |
| **Apple Pencil Battery Percentage Telemetry** | `IPad-Verification-Workspace` Left Rail (`"Apple Pencil: Ready • 94%"`) | `UIKit` and `PencilKit` provide `UIPencilInteraction` (squeeze, double-tap), but Apple does **not** expose public runtime APIs to read connected Apple Pencil battery percentages (restricted to system battery widgets). | Maintain clean system status indicators without fabricated hardware battery telemetry. |
| **Microsecond Hardware Latency Telemetry** | `IPad-Verification-Workspace` Hardware bar (`"14ms latency • ANE"`) | Apple's `Vision` framework (`VNRecognizeTextRequest`) dynamically dispatches to ANE/GPU, but internal hardware execution duration is not exposed in public user-space telemetry. Hardcoding `"14ms"` would be fake data. | Display actual OCR engine confidence (`scan.ocrConfidence`) and engine routing badges (`EngineRouteBadge`) backed by genuine pipeline diagnostics. |
| **Silent In-Place Calendar Rollback ("Undo" CTA)** | `IPad-Verification-Workspace` Success notification banner | Once an `EKEvent` is committed to iCloud via `EventKit`, immediate silent rollback from a quick-action banner is unsafe due to external calendar syncing, shared invitees, and potential concurrency collisions. | Explicit, transactional edits and discards through `EventReviewViewModel` and `SavedEventActions`. |
| **Direct Binary Image Attachment in Apple Calendar Notes** | `IPad-Verification-Workspace` §6 Toggle | In `EventKit`, the `attachments` array on `EKEvent` is restricted to CalDAV/Exchange accounts in standard iOS public APIs. Local write of raw images is unsupported. | Full structured OCR transcription and source metadata are appended to the event's `notes` string, while the raw high-resolution image is stored locally in SwiftData (`ScannedAsset`). |

---

## 3. Rebranding Migration Integrity

### 3.1 Brand Identity Gate Verification
The automated pre-commit brand check (`./scripts/hooks/pre-commit` running `scripts/verify-brand-identity.py --staged`) was executed across all source files, configurations, and test assets:
- **Result:** **PASSED** (0 staged violations).
- **Residual String Check:** No unsupported product-facing legacy branding exists in [`Sources/`](../../Sources/), [`Config/`](../../Config/), or [`Assets.xcassets/`](../../Assets.xcassets/).
- **App Bundle & Display Identity:**
  - `PRODUCT_BUNDLE_IDENTIFIER`: `com.pencild.app`
  - `INFOPLIST_KEY_CFBundleDisplayName`: `Pencil'd`
  - StoreKit configuration: [`Pencild.storekit`](../../Pencild.storekit) with canonical identifiers:
    - `com.pencild.plus.monthly`
    - `com.pencild.plus.annual`
    - `com.pencild.premium.monthly`
    - `com.pencild.premium.annual`
    - `com.pencild.plus.lifetime` (non-consumable; introductory offer, added 2026-10-13)
    - `com.pencild.premium.lifetime` (non-consumable; introductory offer, added 2026-10-13)

### 3.2 Legacy Identifier Shims in Code
**Status (2026-10-12): Retired.** The legacy `DS*`/`ds*` style layer has been removed. The zero-caller color aliases, `DSTypography`, `DSConfidencePill`, and `DSDateBadge` were deleted. The live card, background, and button styles were renamed to `PDGlassCardModifier`/`pdGlassCard`, `pdScreenBackground`, `PDPrimaryButtonStyle`, and `PDSecondaryButtonStyle`. The only remaining `DS`-prefixed identifier is the Info.plist key `DSEnhancedInterpretationRollout`. It is configuration rather than styling, so it is kept for compatibility.

---

## 4. Design System & Styling Token Conformance

The design specification mandates the **Luminous Precision** system (`Plus Jakarta Sans`, deep indigo surfaces `#101127`, sunset gradient `#ff7a00` $\rightarrow$ `#ff7288` $\rightarrow$ `#670fac`, and strict 44pt touch targets).

### 4.1 Canonical Token Adoption & Migration Closeout
All product-facing views across [`Sources/Pencild/Views/`](../../Sources/Pencild/Views/) have been successfully migrated to the canonical `PencilTokens` system (`Color.pd*`, `PDRadius`, `PDSpacing`, `PDStatusBadge`, `PDFont`):
- **`Color.ds*` Call Sites:** 0 call sites remain in production view code. All views resolve directly to `pdSurface`, `pdPrimary`, `pdOnSurface`, `pdWarning`, `pdError`, and related roles. The legacy static aliases in [`Theme/Colors.swift`](../../Sources/Pencild/Theme/Colors.swift) were deleted on 2026-10-12.
- **Modifiers & Badges:** `DSConfidencePill` usage replaced by `PDStatusBadge` (the type itself was deleted on 2026-10-12). The screen canvas modifier is now `.pdScreenBackground()`.
- **Magic Numeric Values:** Replaced with semantic tokens across forms and review surfaces (`PDRadius.card`, `PDRadius.tile`, `PDRadius.pill`, `PDSpacing.md`, `PDSpacing.sm`).

---

## 5. Overly Long / Monolithic View Decomposition

The monolithic views identified in earlier passes have been decomposed into focused, single-responsibility components:

| File | Pre-Remediation Baseline | Post-Decomposition Baseline | Extracted Sub-Components |
| :--- | :---: | :---: | :--- |
| [`EventReviewEditView.swift`](../../Sources/Pencild/Views/EventReviewEditView.swift) | **1,031** | **568** | [`EventReviewSourceInspector.swift`](../../Sources/Pencild/Views/EventReviewSourceInspector.swift), [`EventReviewFieldsCard.swift`](../../Sources/Pencild/Views/EventReviewFieldsCard.swift), [`EventReviewDestinationCard.swift`](../../Sources/Pencild/Views/EventReviewDestinationCard.swift), [`EventReviewSourceBanner.swift`](../../Sources/Pencild/Views/EventReviewSourceBanner.swift) |
| [`SavedEventDetailView.swift`](../../Sources/Pencild/Views/SavedEventDetailView.swift) | **375** | **315** | [`EventInterpretationDetailCard.swift`](../../Sources/Pencild/Views/EventInterpretationDetailCard.swift) |
| [`BatchReviewView.swift`](../../Sources/Pencild/Views/BatchReviewView.swift) | **685** | **583** | [`BatchDestinationsEditor.swift`](../../Sources/Pencild/Views/BatchDestinationsEditor.swift), `BatchTitledField` |
| [`ScanFlowViews.swift`](../../Sources/Pencild/Views/ScanFlowViews.swift) | **676** | **580** | [`ScanProgressOverlay.swift`](../../Sources/Pencild/Views/ScanProgressOverlay.swift), `PDScanStepRow` |
| [`HomeEmptyStateView.swift`](../../Sources/Pencild/Views/HomeEmptyStateView.swift) | **669** | **669** | Self-contained SwiftUI canvas interaction and intake options. |
| [`PlusPaywallView.swift`](../../Sources/Pencild/Views/PlusPaywallView.swift) | **378** | **378** | Bound to dynamic StoreKit 2 pricing and local-alert restore handling. |
| [`PremiumPaywallView.swift`](../../Sources/Pencild/Views/PremiumPaywallView.swift) | **383** | **383** | Dynamic tier matrix with truthful pricing. |
| [`ReminderScheduleEditorView.swift`](../../Sources/Pencild/Views/ReminderScheduleEditorView.swift) | **282** | **282** | Clean, self-contained preset schedule editor. |

---

## 6. Best Practices, Concurrency, and Crash Safety

### 6.1 Swift 6 Concurrency & Actor Isolation
- **Status:** **EXCELLENT**. The project builds with Swift 6 and `ApproachableConcurrency` enabled without compiler warnings or data races.
- Services (`EventKitManager`, `ExtractionService`, `SubscriptionService`) properly isolate mutating tasks and avoid cross-actor mutations.
- State binding in [`ContentView.swift`](../../Sources/Pencild/ContentView.swift) and `@EnvironmentObject` injection is strictly maintained across all sheet and navigation destinations.

### 6.2 Fatal Errors & Precondition Failures
- An audit for `fatalError()` and `preconditionFailure()` identified:
  - [`ServiceContainer.swift#L72`](../../Sources/Pencild/Services/ServiceContainer.swift#L72): Valid fail-fast assert if `ServiceContainer` is missing at root.
  - [`PurchaseViewModel.swift#L119-L134`](../../Sources/Pencild/ViewModels/PurchaseViewModel.swift#L119-L134): Static URLs initialized with `preconditionFailure`:
    ```swift
    static let privacyPolicy: URL = {
        guard let url = URL(string: "https://getpencild.com/privacy") else {
            preconditionFailure("Invalid Privacy Policy URL")
        }
        return url
    }()
    ```
  - **Assessment:** These URLs are covered by unit tests asserting validity at test time.

### 6.3 StoreKit 2 Truthfulness
- All paywalls ([`PlusPaywallView.swift`](../../Sources/Pencild/Views/PlusPaywallView.swift), [`PremiumPaywallView.swift`](../../Sources/Pencild/Views/PremiumPaywallView.swift)) bind directly to StoreKit products loaded by `PurchaseViewModel`.
- When products fail to load or network is absent, purchases are disabled with user-visible recovery options; no fake fallback products are sold.
- Restore purchase flows properly reflect verification states.
- Purchase buttons show the live StoreKit price or free-trial offer, and show
  "Price unavailable" (disabled) when products have not loaded. A brief change
  in `37eede7` replaced them with fixed "UPGRADE TO …" labels; that was
  reverted on 2026-10-12.

---

## 7. Remediation Execution & Release Closeout Evidence

The implementation, build, test, and artifact-gate portions of the remediation
phases defined in [`docs/plans/2026-10-11-production-readiness-remediation-plan.md`](../plans/2026-10-11-production-readiness-remediation-plan.md)
have been executed and verified against the repository gates. The positive
StoreKit restore and populated iPad runtime smoke items from the plan's next
implementation wave were closed on 2026-10-11 (see §7.3 and §7.4).

### 7.1 Automated Quality Gates
1. **XcodeGen Project Generation:**
   - Command: `xcodegen generate --spec project.yml`
   - Result: Generated clean `Pencild.xcodeproj`.
2. **iPhone 17 Test Suite:**
   - Destination: `platform=iOS Simulator,name=iPhone 17`
   - Metrics: **125 tests across 30 suites**, 123 passed, 2 skipped, 0 failed, 0 warnings.
   - Result Bundle: `/private/tmp/pencild-phase4-current-iphone.xcresult`.
3. **iPad Pro 11-inch (M5) Test Suite:**
   - Destination: `platform=iOS Simulator,name=iPad Pro 11-inch (M5)`
   - Metrics: **125 tests across 30 suites**, 123 passed, 2 skipped, 0 failed, 0 warnings.
   - Result Bundle: `/private/tmp/pencild-phase4-current-ipad-retry.xcresult`.
4. **Release Executable Verification:**
   - Command: `xcodebuild -project Pencild.xcodeproj -scheme Pencild -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build`
   - Verification Tool: `./scripts/verify-release-content.sh --require-app <built-app-path>`
   - Result: **PASSED** (1 Mach-O binary, 74,153 strings, 84,847 symbols; zero mock services or debug-only diagnostic symbols).
5. **Brand Identity Gate:**
   - Command: `./scripts/hooks/pre-commit` (running `scripts/verify-brand-identity.py`)
   - Result: **PASSED** (0 brand violations in staged Git index).
6. **Git Formatting & Whitespace:**
   - Command: `git diff --check`
   - Result: **PASSED** (clean diff).

### 7.2 Accessibility & Human Interface Verification
- **44pt Touch Targets:** Validated across all toolbar buttons, navigation icons, zoom controls, and card actions.
- **Dynamic Type & High Contrast:** All views adapt using standard text styles and luminance-stepped background containers.
- **VoiceOver Semantics:** Verified accessibility labels and hints on icon-only buttons (`zoomIn`, `zoomOut`, `resetZoom`, `dismiss`, `actionOptions`).
- **Reduce Motion:** Animation transitions respect system reduce-motion settings.

### 7.3 StoreKit 2 & Offline Recovery Edges
- Verified truthful product pricing and dynamic localized prices.
- Recovery states verified for unavailable products, user cancellations, pending transactions, empty restores, network failure, and cryptographic verification failure (`PencildError.subscription(.verificationFailed)`).
- Positive local StoreKit restore is verified by
  `Tests/PencildTests/StoreKitRestoreIntegrationTests.swift`. The suite loads the
  repository `Pencild.storekit` directly with `SKTestSession(contentsOf:)`
  (which avoids the scheme-level catalog sync that returned no products in the
  earlier CLI probe), buys `com.pencild.plus.monthly` and
  `com.pencild.premium.annual` out of band, and asserts the real
  `SubscriptionService.restorePurchases()` resolves `.plus` / `.premium`. It also
  covers catalog loading of all four product IDs, empty restore (`.starter`), and
  an expired subscription restoring to `.starter`. Entitlement refreshes are
  serialized (2026-10-12), so a concurrent transaction-update refresh cannot
  make restore report a stale tier. Evidence:
  `/private/tmp/pencild-storekit-restore.xcresult` (iPhone 17).
- Local-first integrity preserved: calendar mutations require explicit user review and confirmation.

### 7.4 Populated iPad Runtime Smoke & Follow-up Fixes
- `Tests/PencildTests/TabletWorkspaceTests.swift` replaces the earlier
  tautological checks (local arithmetic and model-field reads) with a populated
  smoke: the sample flyer is scanned through real Vision OCR and the rules
  pipeline into SwiftData, then Event Review and Saved Event Detail are hosted
  at regular width (1194×834) and compact width, with explicit Save,
  already-saved rescan detection, and archive/restore through
  `SavedEventActions`. Zoom/pan rules now live in the `SourceViewport` value
  type used by the inspector and are tested directly. Screenshots are retained
  in `/private/tmp/pencild-ipad-smoke/` and attached to
  `/private/tmp/pencild-ipad-smoke.xcresult` (iPad Pro 11-inch (M5)).
- The smoke exposed a production layout defect: nine modal screens used the
  deprecated `NavigationView`, which on iPad defaults to the split style and
  rendered Event Review inside a ~536pt sidebar column. All were migrated to
  `NavigationStack` (iOS 17 deployment target).
- Removed the uncalled raw-text `extractCandidates(from: String)` entry point,
  which fabricated per-line OCR confidence (0.95) and synthetic bounding boxes.
- Sweep results: no TODO/FIXME markers, no `fatalError`/`try!`/`print` in
  production sources, no network processing paths (on-device claims hold),
  `ScreenGalleryView` and `MarketingKitView` remain `#if DEBUG`-only, and the
  15 `stitch-id` provenance comments are retained per plan.

### 7.5 Batch Review & Scan Flow Component Alignment (2026-10-12)
- `BatchReviewView` and the scan-flow views (`RecentScreenshotsView`,
  `ReviewQueueView`, `BatchDestinationsEditor`) were aligned to the shared
  `PD*` components and tokens. This closes items 3.1 and 3.2 of the Profile &
  Settings follow-up audit. Line counts grew slightly (583 and 580) because
  regular-width layouts were added. Behavior is unchanged: the same save,
  discard, selection, and batch-scan paths are used.
- `TabletWorkspaceTests` adds `populatedBatchReviewSmoke`, which runs a real
  batch scan with one event and one no-dates source, and `scanFlowSmoke`,
  which covers a populated review queue and the empty screenshot picker. Both
  run at regular and compact width. Before screenshots are in
  `/private/tmp/pencild-batch-before/` and after screenshots are in
  `/private/tmp/pencild-ipad-smoke/`.

### 7.6 Paywall Interstitials (2026-10-12): Done
- **Status: done; no top bar by design.** The Plus and Premium paywalls are
  interstitial sheets that can open from anywhere in the app, so they do not
  use `PDTopBar`: its back chevron means "return to the previous screen".
  Instead they share a pinned `PDInterstitialHeader` whose only control is
  the close button in the top-right corner. The bar is transparent, so the
  screen's ambient gradient reaches the top edge, and it stays visible while
  the paywall content scrolls. Restore Purchases stays in the footer.
- Layout, top to bottom: the eyebrow; an "Upgrade to Plus" / "Upgrade to
  Premium" headline (the previous headline is folded into the description);
  the included-features list; the "You stay in control" card; the billing-
  period options; then the purchase button.
- On Premium, "PDF & Files import" is listed directly after "Everything in
  Plus" and is highlighted: a bold title on the highlight-card gradient.
- Billing periods use the shared `PDPlanOption`. The selected option fills
  with the action gradient and a checkmark; the earlier left-edge bar is
  removed. This replaces four duplicated plan-card implementations.
- The intro eyebrow now has top spacing below the pinned header.
- Saved Event Detail is also only ever presented as a sheet (after Save, from
  notifications, and from Batch Review). It now uses the shared top-right
  `PDCloseButton` instead of `PDTopBar`'s back chevron, which did not read as a
  way to close the screen.
- Verified by `paywallInterstitialsRender` in `TabletWorkspaceTests` at
  regular and compact width.

### 7.7 Screenshot Extraction Grounding (2026-10-13)
- **Undated screenshots no longer become events.** Every screenshot carries a
  status-bar clock. The `NSDataDetector` fallback read a bare time ("9:41") or
  a vague phrase ("last night") as today and rolled it forward a year, which
  fabricated a date for chats, notes, and other undated screenshots and filled
  the Review queue. A bare clock in the top strip of the image is now dropped
  before extraction, and a fallback match must name a month, weekday, or
  numeric date. The status-bar time also no longer becomes an event's start
  time.
- **Titles come from the most prominent line.** Title ranking had weighted
  line width (0.45) above type size, measured "size" as height divided by
  character count, and penalised flyer words such as LIVE and FREE, so a wide
  description line could beat a large headline. Ranking now uses rendered
  line height first, keeps width as a minor signal, and penalises
  sentence-like body copy.
- Covered by `ScreenshotGroundingTests` (7 tests). Three of them fail on the
  previous extraction code.
- Candidates created before this fix stay in the Review queue until they are
  discarded.

### 7.8 Lifetime Introductory Offer (2026-10-13)
- Both paywalls offer a third billing period, **Lifetime**: a one-time,
  non-renewing purchase (`com.pencild.plus.lifetime`,
  `com.pencild.premium.lifetime`). Local StoreKit test prices are $39.99 and
  $79.99; live prices come from App Store Connect.
- The option is an introductory promotion. `LifetimeIntroOffer` shows it
  through April 13, 2027 and hides it from April 14. Owners keep their
  entitlement after the window closes.
- Billing is modeled by `BillingPeriod` (monthly, annual, lifetime), replacing
  the paywalls' `annual: Bool`. `SubscriptionCatalog` is the single source of
  product IDs; `SubscriptionService.productIdentifiers` now reads from it.
- Manage Plan shows lifetime owners "Lifetime access" and "One-time purchase ·
  never renews", with no renewal status.
- Evidence: `LifetimeOfferTests` covers the promo window, catalog coverage,
  non-expiring resolution, and refunds. `StoreKitRestoreIntegrationTests`
  buys each lifetime product through StoreKitTest and restores the right tier.
- **Release prerequisite:** create both non-consumable products in App Store
  Connect with these exact IDs before submission. Ending the promotion on
  the App Store side (removing the products from sale) is a separate manual
  step.

### 7.9 Free Plan Limits and Paywall-on-Attempt (2026-10-13)
- **Free plan:** 10 scans per calendar month, counting only scans that find a
  new event (failed, no-date, and resumed scans don't count), and 1 alert per
  event. Plus and Premium have unlimited scans and up to 3 alerts per event.
  Event history is not limited on any plan. The numbers live in `PlanLimits`.
  The monthly count is stored locally by `ScanUsageStore`, which is injected
  through `ServiceContainer` so tests use an ephemeral store.
- **Subscribers are never limited by mistake.** While entitlements are still
  being checked, paid allowances apply.
- **Every Plus and Premium feature stays visible to all users.** Attempting a
  feature without the entitlement opens the paywall instead of running it:
  - Scanning past the allowance opens the Plus paywall.
  - Batch scans are checked before they start, so items are never skipped
    silently. If the selection is larger than the free scans left, the user is
    asked to **deselect** the excess, **upgrade to Plus**, or **discard** the
    selection; nothing is scanned until they choose.
    - In the in-app screenshot grid, Deselect keeps selection mode with a live
      "Deselect N more" hint, and the paywall opens over the grid so the
      selection survives.
    - From the Photos picker, Deselect reopens it with the selection intact.
    - From the document camera, the trim option is "Scan First N Pages".
    - After upgrading from Home, the chosen batch runs automatically.
    - A batch can't use more scans than it has items, so one that passes this
      check can't run out partway through. The in-batch upgrade row stays only
      as a safety net.
  - In the reminder schedule editor, adding an alert past the limit or picking
    a multi-alert preset opens the Plus paywall. These controls are no longer
    disabled.
  - On the free plan, the Auto-detect switch shows off, and turning it on opens
    the Plus paywall.
  - Already in place: Likely events, PDF & Files import, the Duplicates
    filter, and deadline reminders each open the matching paywall.
- Home shows free users "N of 10 free scans left this month" with an Upgrade
  button. The Plus paywall lists "Unlimited scans" and "Up to 3 alerts per
  event". The StoreKit product descriptions no longer claim "unlimited event
  history", which was never a feature.
- Removed the unused `addOffset`/`removeOffset` from `EventReviewViewModel`.
- Evidence: `PlanLimitsTests` covers the monthly reset, who is limited, counting
  only new events, blocking when exhausted, Plus being unlimited, the batch
  flag, and alert caps on review.

### 7.10 Event Review, Batch Review, and Saved Event Detail Flow (2026-10-13)
- All three screens use one section order: needs-attention items (duplicates,
  questions, ambiguous dates); **Event details**; alternative readings and
  **Suggestions**; **Calendar & reminders** (with Alerts); **On the flyer**;
  the primary action; then the source and "Why Pencil'd chose these details".
- Fixed: Event Review placed the "Calendar & reminders" heading below the
  destination card, above the suggestions. On iPhone, scan details sat above
  Save. Saved Event Detail put the source between destinations and alerts.
- **Suggestions render only when there is something to suggest**, so there
  is no empty heading. Previously the card showed a bare "SUGGESTIONS" label
  when the alert plan differed but the user lacked Premium or the plan was
  empty. Each suggestion says what "Use" changes ("Use sets the end time",
  "Use replaces your current alerts"). On free plans, the Premium alert-plan
  suggestion is shown with a Premium button that opens the paywall.
- Batch Review's expanded card now includes the same Suggestions section and a
  "Calendar & reminders" heading. "Other interpretations" moved from scan
  details to directly after Event details, since choosing one changes the
  fields.
- Verified with full-length renders: `10-compact-review-full` and
  `11-compact-detail-full` in `TabletWorkspaceTests`.

