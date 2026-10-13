# Profile & Settings Refresh: Implementation Verification & Follow-up Audit

**Date:** 2026-10-10  
**Author:** AI Agent (Profile & Settings Owner)  
**Governing Plan:** `docs/plans/2026-10-10-pencild-visual-refresh-plan.md`  
**Design Spec:** `pencild-design-system-updated.md`  
**Shared Components:** `Sources/Pencild/Views/PencilComponents.swift`  
**Shared Tokens:** `Sources/Pencild/Theme/PencilTokens.swift`  

---

## 1. Executive Summary

This audit records the completion of the visual refresh and component migration for all Profile and Settings screens in Pencil'd, adhering strictly to production-quality implementation without mock or hard-coded production data. All screens now utilize the canonical design tokens (`Color.pd*`, `PDFont.*`, `PDSpacing.*`, `PDRadius.*`, and `LinearGradient.pd*`) and shared components in `PencilComponents.swift` (`PDTopBar`, `PDScreenIntro`, `PDCard`, `PDGroupedList`, `PDListRow`, `PDToggleRow`, `PDIconTile`, `PDStatusBadge`, `PDChip`, and `PDGradientButtonStyle`).

In addition, this audit documents critical findings in neighboring modules encountered during build and test verification, scoped for subsequent development sessions.

---

## 2. In-Scope Surfaces: Delivery & Verification

All seven assigned surfaces have been refactored and verified:

### 2.1 Settings Root (`SettingsHubView.swift`)
- **Visual & Structural Architecture:**
  - Modernized with `PDTopBar(title: "Settings", showsBack: false)` with integrated 44pt circular Profile button.
  - Screen overview driven by `PDScreenIntro`.
  - Subscription card migrated to `PDCard(highlighted: true)` with `PDStatusBadge` (Active/Free) and `PDGradientButtonStyle` for management CTA.
  - Permissions inspection (`Photos`, `Calendar`, `Notifications`) unified under `PDGroupedList` and `PDListRow` with dynamic status badges (`PDStatusBadge`).
  - Navigation rows (`Default Calendar`, `Default Reminders`, `Source Preferences`) unified using `PDGroupedList` and `PDListRow` with `PDValueChevron`.
  - App default switch for "Automatic Capture" using `PDToggleRow`.
  - Privacy highlight card with `PDIconTile` and direct routing to Privacy Center.
  - Adaptive two-column layout for iPad / regular size classes preserved without regression (`horizontalSizeClass == .regular`).
- **Data Integrity:**
  - Zero hard-coded permission states: uses live `services.photoLibrary.authorizationStatus(for: .readWrite)`, `services.calendar.authorizationStatus()`, and `services.notifications.authorizationStatus()`, refreshing dynamically on `scenePhase` changes.
  - Real StoreKit subscription tier (`appState.subscriptionTier`) and StoreKit restore flow (`purchases.restore()`).

### 2.2 Default Calendar (`DefaultCalendarView.swift`)
- **Visual & Structural Architecture:**
  - Unified with `PDTopBar`, `PDScreenIntro`, and `PDCard` sync overview.
  - Calendar groups partitioned with `PDSectionHeader` and styled selection rows with interactive checkmark rings.
  - "Ask Every Time" toggle integrated into a `PDCard` using `PDToggleStyle`.
- **Data Integrity:**
  - Live EventKit connection via `services.calendar.writableCalendars()` and `systemDefaultCalendar()`.
  - Real persistence via `DefaultCalendarStore`, supporting both specific calendar selection and zero-conflict reset to iOS system default.

### 2.3 Reminder Presets (`ReminderSettingsView.swift`)
- **Visual & Structural Architecture:**
  - Header and intro styled with `PDTopBar` and `PDScreenIntro`.
  - Preset bundle cards ("Same Day Focus", "Day Before + Morning", "Comprehensive 3-Stage", "Custom") styled with `PDCard`, `PDStatusBadge`, and `LinearGradient.pdSelected` when active.
  - Live dynamic schedule preview box with relative time indicators.
  - Individual stage rules wrapped in `PDGroupedList` with `PDToggleRow`.
- **Data Integrity:**
  - Live persistence to `ReminderPresetStore`.
  - Dynamic preview date calculations using `Calendar.current` offsets from an active reference date (no hardcoded dates).

### 2.4 Privacy & Processing Center (`PrivacyCenterView.swift`)
- **Visual & Structural Architecture:**
  - Converted from legacy `dsGlassCard` to `PDTopBar`, `PDScreenIntro`, and `PDCard(highlighted: true)`.
  - Feature badges use `PDChip` and `PDStatusBadge`.
  - Processing Architecture modes (Strict Local Isolation vs. Enhanced Hybrid) styled with selection cards and `LinearGradient.pdSelected`.
  - Local Cache & Data Lifecycle toggles embedded in `PDGroupedList` with `PDToggleStyle`.
  - Storage actions and Legal links grouped in `PDGroupedList` using `PDListRow`.
- **Data Integrity:**
  - Real execution of `SavedEventActions(services: services, modelContext: modelContext).clearScanCache()` and `eraseAllLocalData()`.
  - Confirmation dialog preserved for destructive reset without deleting Apple Calendar/Reminders events.

### 2.5 Automatic Capture Settings (`AutomationSettingsView.swift`)
- **Visual & Structural Architecture:**
  - Master radar switch hero card with `PDIconTile`, `PDStatusBadge(text: "LIVE", tone: .success)`, and `PDToggleStyle`.
  - Privacy vault card highlighting on-device neural privacy and zero cloud telemetry.
  - Discovery sensitivity tier selector (High Confidence, Balanced, Broad) styled with `PDStatusBadge` and `LinearGradient.pdSelected`.
  - Monitored assets and pace switches grouped in `PDGroupedList` with `PDToggleRow`.
- **Data Integrity:**
  - Bound to live Apple Intelligence capability check via `IntelligenceComposition.currentCapability()`.
  - Real AppStorage bindings for radar enablement, sensitivity tiers, and asset monitoring.

### 2.6 User Profile (`UserProfileFlowView.swift`)
- **Visual & Structural Architecture:**
  - Top bar and intro styled with `PDTopBar(title: "Profile", showsBack: true)` and `PDScreenIntro`.
  - Identity card with signature gradient ring (`LinearGradient.pdSignature`), Apple ID verification status (`PDStatusBadge`), and native `SignInWithAppleButton` / Sign out actions.
  - Activity metrics grid featuring 4 tiles (`PDCard`) showing real user counts.
  - Account Details and Pipeline & Preferences grouped in `PDGroupedList` using `PDListRow` and `PDValueChevron`.
  - In-place name editing alert with device-only persistence.
- **Data Integrity:**
  - Zero mock data: queries live SwiftData `SavedEvent` records via `@Query` for total saved, this week's additions, reminders set, and archived counts.
  - Real Sign in with Apple integration via `ASAuthorizationAppleIDCredential` and background credential validation on appear (`ASAuthorizationAppleIDProvider().credentialState(forUserID:)`).

### 2.7 Help & Feedback (`HelpFeedbackView.swift`)
- **Visual & Structural Architecture:**
  - Adopted `PDTopBar`, `PDScreenIntro`, and refined search bar matching Luminous Precision tokens.
  - Quick troubleshooting 2-column grid using `PDCard` and `PDIconTile`.
  - Frequently Asked questions list rendered in `PDGroupedList` with smooth accordion disclosure and `PDRowDivider`.
  - Support contact actions and sanitized diagnostic summary copy using `PDGroupedList`, `PDListRow`, and `PDGradientButtonStyle`.
- **Data Integrity:**
  - Real system diagnostics generation (`Bundle.main` version and build, `UIDevice.current.systemVersion`).
  - Native mailto handoff to `support@pencild.app` and native sheet presentation for topic guides.

---

## 3. Findings & Out-of-Scope Items for Subsequent Sessions

During baseline verification and project compilation, the following issues in neighboring files outside the Profile & Settings scope were identified and require dedicated follow-up:

### 3.1 `BatchReviewView.swift` & Batch Pipeline
- **Observation:** `BatchReviewView` had mismatched initializer parameters and an unclosed `VStack` in its header. A minimal compiler fix was applied to keep the project buildable.
- **Recommendation:** Perform a dedicated refactoring of `BatchReviewView.swift` to fully align with `PDTopBar`, `PDScreenIntro`, `PDCard`, `PDSectionHeader`, and `PDGroupedList`, retiring all remaining `dsGlassCard` calls.
- **Status (2026-10-12): Resolved.** Event cards use `PDCard`; detected events and skipped screenshots each sit under a `PDSectionHeader`, with skipped rows in a `PDGroupedList`. The Save All bar and content are width-capped on iPad, and spacing and radii use `PDSpacing`/`PDRadius`. No `dsGlassCard` callers remain anywhere. Verified by `populatedBatchReviewSmoke` in `TabletWorkspaceTests`.

### 3.2 `ScanFlowViews.swift` & Review Queue
- **Observation:**
  - Escaped keypath syntax (`\\EventCandidate.createdAt`) in the SwiftData sort descriptor caused compilation failure and was corrected to `\EventCandidate.createdAt`.
  - `EventReviewViewModel.discard(...)` returns a three-case `MutationResult` (`.success`, `.partial([String])`, `.failure(...)`). Call sites must handle all cases exhaustively.
  - `DSConfidencePill` requires both `score: Int` and `label: String`.
- **Recommendation:** Audit the entire extraction and scan flow views for any remaining deprecated `ds*` styling tokens.
- **Status (2026-10-12): Resolved.** No `ds*`/`DS*` style names remain in the codebase (`DSConfidencePill` was deleted with zero callers). `RecentScreenshotsView` replaced the system navigation title and four toolbar buttons with `PDTopBar` plus a single Select/Cancel action, and its empty state uses `PDCard`. On iPad, `ReviewQueueView` lays out cards in two columns and caps its bottom action bar. Verified by `scanFlowSmoke` in `TabletWorkspaceTests`.

### 3.3 `HomeEmptyStateView.swift` & `AgendaView.swift`
- **Observation:**
  - `HomeEmptyStateView.swift` referenced a non-existent `tint` parameter in `DSPrimaryButtonStyle`.
  - `AgendaView.swift` invoked `appState.openHistory()`, which is not a method on `AppState` (navigated via `appState.selectedTab = .history`).
- **Recommendation:** Audit all `AppState` navigation helper methods to ensure consistent naming conventions (`selectedTab`, `activeModal`, `pendingRoute`).
- **Status (2026-10-12): Resolved.** Navigation audit findings and fixes:
  - **One way to show a modal.** 13 call sites (including the `ContentView` deep link) assigned `activeModal` directly, and `review(_:)` did too, while 11 used `present(_:)`. All now go through `present(_:)`, which dismisses an open sheet first. `review(_:)` is now async and routes through `present`.
  - **Navigation lives in `AppState`.** `present(_:)` and `handleScanOutcome(_:)` moved out of an extension in `ScanFlowViews.swift` into a `// MARK: - Navigation` section of `AppState.swift`. The deep-link presentation moved from `ContentView` into `presentDeepLinkedEvent(_:)`.
  - **One dismissal delay.** Three copies of dismiss, sleep, then present (400ms, 400ms, and 350ms) collapsed into `dismissPresentedSheets()` and `AppState.sheetDismissalDelay`.
  - **Typed settings routes.** `SettingsState.pendingRoute` changed from `String?` (raw values parsed back) to `SettingsRoute?`. The Screen Gallery's `""` sentinel became `opensSettingsHub`.
  - **Bug fixed.** Batch Review's "open existing event" action for a possible duplicate silently did nothing, because the root could not stack a second sheet. It now opens in a sheet hosted by Batch Review, so unsaved batch edits are kept.
  - **Naming conventions.** State is a noun (`selectedTab`, `activeModal`, `batchReviewSession`, `showHistory`), presentation helpers start with `present`/`open`, and one-shot commands use `request*` (`requestPhotoPicker`, `requestFileImporter`).
  - Covered by `AppStateNavigationTests`.

### 3.4 Paywalls & History Views (`PlusPaywallView.swift`, `PremiumPaywallView.swift`, `HistoryArchiveView.swift`)
- **Observation:** The paywalls and history views still use legacy `dsGlassCard` and `DSTypography` calls.
- **Recommendation:** In the planned monetization and archive work sessions, migrate these views to `PencilComponents.swift` (`PDCard`, `PDTopBar`, `PDSectionHeader`, `PDStatusBadge`).
- **Status (2026-10-12): Mostly resolved.** All three views now use `PDCard` and `PDSectionHeader`, and `DSTypography` has been deleted. `HistoryArchiveView` uses `PDTopBar`. The two paywalls deliberately do not use `PDTopBar`. They are interstitial sheets and share `PDInterstitialHeader`, with Restore on the leading edge, an "Upgrade to …" title, and close in the top-right corner. See §7.6 of the production readiness audit. **Resolved by design.**

---

## 4. Verification & Quality Gate Compliance

- **XcodeGen Specification:** `project.yml` is aligned; no manual edits to `.xcodeproj` file structure.
- **Compilation Gate:** `xcodebuild -project Pencild.xcodeproj -scheme Pencild -destination 'platform=iOS Simulator,name=iPhone 17' build` completes with exit code 0.
- **Accessibility:** All actionable rows and buttons meet or exceed the 44pt minimum touch target size. Dynamic Type is supported via `PDFont.*`. Confidence indicators combine icon, text label, and color.
- **Local-First Invariant:** All data operations remain 100% on-device. No telemetry or remote cloud dependencies were added.
