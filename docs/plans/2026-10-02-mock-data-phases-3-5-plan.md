# DateSnap Mock Data Phases 3-5 Plan

## Phase 3 — Eliminate production fallbacks that misrepresent state

### Task 3.1: Remove hard-coded paywall price fallbacks
- **Files:** `PlusPaywallView.swift`, `PremiumPaywallView.swift`, `PurchaseViewModel.swift`, `ManagePlanView.swift`
- **Changes:**
  - `PurchaseViewModel.displayPrice(_:annual:fallback:)`: Remove `fallback` parameter; return `product?.displayPrice` only. If product is nil, return empty string and disable purchase CTA.
  - `PurchaseViewModel.monthlyEquivalent(_:fallback:)`: Remove `fallback` parameter; return `(annual.price / 12).formatted(annual.priceFormatStyle)` only when product exists.
  - `PlusPaywallView.ctaTitle`: Use `purchases.displayPrice(.plus, annual: ...)` without fallback; if product is missing, CTA shows "Subscribe" with disabled state.
  - `PremiumPaywallView.ctaTitle`: Same pattern for `.premium`.
  - `PlusPaywallView.savingsText`: Guard: only compute when both monthly and annual products exist; otherwise "Best Value" with no price display.
  - `PremiumPaywallView.savingsText`: Same.
  - Paywall Buttons: `.disabled()` added for `purchases.isLoadingProducts || purchases.product(.plus/premium, annual: ...) == nil` to block taps when StoreKit products are unavailable.
- **Tests:** `PurchaseViewModelTests` — verify `displayPrice` returns only StoreKit-derived price; verify empty string when product unavailable; verify CTA disabled state.

### Task 3.2: Replace silent `try?` with typed mutation results
- **Files:** SwiftData save/delete paths, Calendar/Reminder cleanup, Privacy Center "clear cache", event review reminder creation
- **Changes:**
  - Replace `try? context.save()` with explicit `Result` type: `save() -> .success, .partial([failedIDs]), .failure(Error)`.
  - Privacy Center "clear cache": return `.success` only if SwiftData purge succeeded; `.partial` for records that were already clean; `.failure` for persistent error.
  - Calendar/Reminder cleanup: return typed result instead of unconditional toast.
  - Event review reminder creation: surface failure via `errorMessage`; only toast success on confirmed success.
  - Keep deliberate parser/OCR fallbacks (e.g., `recognizeWithRetry` in ScanViewModel, rule-based analyzer) — these are resilience, not mocks.
- **Tests:** Failure-injection tests for each mutation path inject errors and verify typed results are surfaced; success UI only appears after confirmed success.

### Task 3.3: Replace hard-coded status/usage displays with live data or remove them
- **Files:** `PrivacyCenterView.swift`, `ReminderSettingsView.swift`, `AutomationSettingsView.swift`, `SettingsHubView.swift`
- **Changes:**
  - `PrivacyCenterView`: Remove hard-coded "24.8 MB of 50 MB cap," "18 event snapshots cached," 50% usage bar, "AES-256 GCM," "Strict socket firewall," "Certified on iOS 18 Local Sandbox Architecture." Replace with on-device computed values where available or remove/omit.
  - `ReminderSettingsView`: The "Active Simulation" static OCT 24 event renaming to "Preview"; derive from real configured offsets; remove hard-coded date text.
  - `AutomationSettingsView`: Remove unimplemented claims ("Ready & Listening," background listeners, Share Sheet, smart auto-save, digest, evening digest, low-power throttling, camera/AirDrop scopes). Retain only the real enhanced-interpretation toggle.
  - `SettingsHubView`: Remove or replace any production-visible status claims not backed by live data.
- **Tests:** Verify each removed claim is absent from Release binary; retained live values are derived from actual service state.

### Task 3.4: Resolve signing placeholders (F-11)
- **Files:** `Config/DateSnap-Release.xcconfig`, `Config/DateSnap-Debug.xcconfig`, `ExportOptions-AppStore.plist`
- **Changes:**
  - Remove `DEVELOPMENT_TEAM =` placeholder lines entirely — let Xcode resolve the team from the selected Apple ID.
  - `ExportOptions-AppStore.plist`: Remove any placeholder team ID; keep `signingStyle = automatic`.
  - Document the required input in `docs/runbooks/RELEASE.md`: "Ensure the Apple Developer account is selected in Xcode > Settings > Accounts. The `DEVELOPMENT_TEAM` xcconfig entry must be omitted (Xcode fills it automatically)."
  - Flag as owner action: a human must confirm the Release archive signs with a valid Apple Distribution identity.
- **Tests:** Archive build resolves team ID; `codesign -d --entitlements :- <App.app>` shows no `YOUR_TEAM_ID` placeholder.

## Phase 4 — Preserve legitimate demos and resilience

### Task 4.1: Keep SampleFlyer as explicit demo content
- **Files:** `SampleFlyer.swift`, `ScanViewModel.swift` (scanSampleFlyer)
- **Changes:** No automatic external write. The `scanSampleFlyer` method routes through the real OCR → extraction → understanding pipeline. Add a test that verifies it produces a future review candidate without granting Photos access.
- **Exit criteria:** Release QA proves the sample uses production OCR/extraction and is clearly labeled as a sample.

### Task 4.2: Keep rules-only intelligence and parser fallbacks
- **Files:** `EventExtractionService.swift`, `RuleBasedEventAnalyzer.*`, `Intelligence/*`
- **Changes:** These are production resilience paths, not mocks. Keep them. Document which paths are rules-only vs. model-driven.
- **Tests:** Tests confirm rules-only paths produce valid output without on-device model dependency.

### Task 4.3: Add tests distinguishing intentional demo/fallback paths
- **Files:** `Tests/DateSnapTests/`
- **Changes:** Add test cases that specifically verify:
  - `scanSampleFlyer` uses the real pipeline (OCR + extraction + understanding) but does not grant Photos permission.
  - Paywall CTA is disabled when products are unavailable (not mocked).
  - Debug-only routes compile out of Release.
- **Tests:** New test suite `MockDataCleanupTests`.

### Task 4.4: Keep Debug fixtures compiled only under `#if DEBUG`
- **Files:** `ContentView.swift` (screenGallery), `ScreenGalleryView.swift`, `DateSnapEvent` sample fixtures
- **Changes:** Verify `#if DEBUG`/`#else` guards are present and effective. Consider moving gallery and fixtures to a Debug-only source set/target.
- **Exit criteria:** Release binary scan finds no sample event titles, Stitch IDs, gallery copy, or debug simulation labels.

### Task 4.5: Mark historical plans as historical (F-12)
- **Files:** `docs/audits/2026-10-01-production-readiness-audit.md`, `docs/plans/2026-10-01-production-readiness-implementation-plan.md`, `AGENTS.md`
- **Changes:** Annotate older planning documents as historical; do not delete audit history; do not edit `AGENTS.md` (list as owner-approval follow-up only).
- **Exit criteria:** Historical documents are clearly labeled; `AGENTS.md` unchanged except for a note linking to the latest audit.

## Phase 5 — Prove cleanup completeness

### Task 5.1: Add scripts/verify-no-mock.sh with allowlist
- **Files:** `scripts/verify-no-mock.sh`, `scripts/mock-allowlist.txt`
- **Changes:**
  - `scripts/verify-no-mock.sh`: Repo scan with grep for:
    - `Mock` identifier prefixes
    - Known sample titles (e.g., "NEON SUNSET", "ROOFTOP SESSION", "SUMMIT_2025.PDF")
    - Stitch IDs
    - "Simulation Hub"
    - Hard-coded price patterns (`\$\d+\.\d{2}`)
    - `try?` in mutation paths (SwiftData saves/deletes, Calendar/Reminder cleanup, Privacy Center clear cache)
    - TODO/FIXME/HACK/XXX/TBD markers
  - `scripts/mock-allowlist.txt`: Coverage file listing allowlisted items with owner and reason:
    - Tests/ previews (named fixtures)
    - SampleFlyer (intentional demo)
    - Historical docs (marked as historical)
    - Debug-only `#if DEBUG` code
  - Script exits nonzero on any unallowlisted hit.
- **Tests:** Script runs clean on the repository.

### Task 5.2: Build Release archive, inspect binary strings/symbols
- **Commands:** `xcodebuild -archivePath DateSnap.xcarchive archive -scheme DateSnap -configuration Release`
- **Inspection:** `strings <App.app> | grep -i "NEON SUNSET\|ROOFTOP SESSION\|SUMMIT_2025\|Simulation Hub\|datesnap-sample"` — must find nothing.
- **Save output:** Archive inspection results.

### Task 5.3: Write setting-to-consumer ledger
- **File:** `docs/audits/2026-10-02-settings-consumer-ledger.md`
- **Format:** For each visible Settings control, record:
  - The observable downstream effect
  - The test that proves it
- **Coverage:** All SettingsState properties and visible controls.

### Task 5.4: Add failure-injection tests
- **Files:** `Tests/DateSnapTests/`
- **Tests added:**
  - StoreKit: products unavailable → CTA disabled, no hard-coded price displayed
  - SwiftData: save failure → typed `.failure` result, no success toast
  - SwiftData: delete failure → typed `.failure` result
  - Calendar: create event failure → error surfaced, no unconditional success
  - Reminders: create reminder failure → error surfaced
  - Notifications: permission denied → graceful flow
  - Photos: denial → proper alert and system-picker fallback
  - OCR: failure → error surfaced, fallback used appropriately
  - Foundation Models: disabled/grayed out when not available
  - Offline mode: app functions without network, no mock services activated

### Task 5.5: List every allowlisted item with owner and reason
- **Format:** Table of allowlisted items, owner, reason, pending signoff status.
- **Pending owner signoff:** All items that require human confirmation.