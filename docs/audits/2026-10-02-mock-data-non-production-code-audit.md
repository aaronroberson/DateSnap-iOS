# DateSnap Mock Data, Mock Features, Non-Production Code, and TODO Audit

Date: 2026-10-02

## Objective

Identify repository-visible mocks, fakes, samples, simulation paths, placeholders, hard-coded production fallbacks, unfinished settings, debug utilities, and TODO-style debt that could ship misleading or nonfunctional behavior. The goal is to replace production-facing simulation with real functionality, remove unsupported claims, isolate legitimate development fixtures from Release, and define evidence that gives the team confidence the cleanup is complete.

## Audit outcome

**No-go for representing every visible Settings and Privacy feature as production-ready.** The core scan, OCR, EventKit, notification, SwiftData, StoreKit, and on-device interpretation paths have real implementations. However, the application target also contains an always-successful mock service graph, and multiple production-visible screens expose state or claims that are not connected to production behavior.

The most serious issues are:

1. Mock services are compiled into the application target and are the default SwiftUI environment dependency.
2. Most `SettingsState` values are transient presentation state with no service/view-model consumers.
3. Automation screens claim background/opportunistic scanning, smart auto-save, Share Sheet support, capture scopes, digests, and energy throttling that are not implemented in the reviewed code.
4. Privacy Center displays fabricated storage metrics, encryption/certification badges, permission states, and a “strict socket firewall” claim without supporting implementation.
5. Reminder settings include static simulation data and controls that do not drive event/reminder scheduling.
6. Paywalls display hard-coded fallback prices when StoreKit products are unavailable.

No `TODO`, `FIXME`, `HACK`, `XXX`, `TBD`, `WIP`, “not implemented,” or source-code placeholder markers were found under `Sources/DateSnap`. Absence of markers does not mean the features are complete; the largest gaps are polished UI states with no runtime integration.

## Inputs reviewed

### Dependency and mock infrastructure

- `Sources/DateSnap/DateSnap.swift`
- `Sources/DateSnap/ContentView.swift`
- `Sources/DateSnap/Services/ServiceContainer.swift`
- `Package.swift`
- `project.yml`

### Sample and debug infrastructure

- `Sources/DateSnap/Services/SampleFlyer.swift`
- `Sources/DateSnap/ViewModels/ScanViewModel.swift`
- `Sources/DateSnap/Models/EventModels.swift`
- `Sources/DateSnap/Views/ScreenGalleryView.swift`
- `Sources/DateSnap/Views/HomeEmptyStateView.swift`
- `Sources/DateSnap/Views/ScanFlowViews.swift`
- `Sources/DateSnap/Views/InterpretationDiagnosticsView.swift`
- `Sources/DateSnap/Views/EventReviewEditView.swift`

### Production-visible settings and claims

- `Sources/DateSnap/Models/SettingsState.swift`
- `Sources/DateSnap/Views/AutomationSettingsView.swift`
- `Sources/DateSnap/Views/ReminderSettingsView.swift`
- `Sources/DateSnap/Views/PrivacyCenterView.swift`
- `Sources/DateSnap/Views/SettingsHubView.swift`
- `Sources/DateSnap/Views/ManagePlanView.swift`
- `Sources/DateSnap/ViewModels/PurchaseViewModel.swift`
- `Sources/DateSnap/Views/PlusPaywallView.swift`
- `Sources/DateSnap/Views/PremiumPaywallView.swift`
- `Sources/DateSnap/Views/HelpFeedbackView.swift` (search-based claim review)

### Production service/error behavior

- `Sources/DateSnap/Services/SubscriptionService.swift`
- `Sources/DateSnap/Services/PhotoLibraryService.swift`
- `Sources/DateSnap/Services/CalendarService.swift`
- `Sources/DateSnap/Services/ReminderService.swift`
- `Sources/DateSnap/Services/NotificationService.swift`
- `Sources/DateSnap/Services/SavedEventActions.swift`
- `Sources/DateSnap/Services/Intelligence/EventUnderstandingPipeline.swift`
- `Sources/DateSnap/Services/EventExtractionService.swift` (fallback/search review)

### Configuration and release evidence

- `Config/DateSnap-Debug.xcconfig`
- `Config/DateSnap-Release.xcconfig`
- `ExportOptions-AppStore.plist`
- `DateSnap.storekit`
- `docs/runbooks/RELEASE.md`
- `docs/runbooks/TESTFLIGHT-QA.md`
- Existing audit and implementation-plan documents under `docs/audits/` and `docs/plans/`

### Repository searches performed

- TODO/FIXME/HACK/XXX/TBD/WIP/stub/placeholder patterns
- mock/fake/sample/demo/simulation/preview patterns
- `#if DEBUG`, simulator checks, timers, sleeps, hard-coded URLs and credentials
- silent `try?`, generic catches, fallback values, empty/nil/always-success returns
- Settings property consumers in `Services/` and `ViewModels/`
- sample-event references and StoreKit fallback prices

## Classification policy

| Classification | Meaning | Required treatment |
|---|---|---|
| Remove | No production value or misleading behavior | Delete from product target and references |
| Replace | Production UI promises a feature | Implement real behavior and tests, or remove the UI/claim |
| Isolate | Useful only to previews/tests/debugging | Move to test/preview support or compile out of Release |
| Retain | Intentional production sample/fallback with real behavior | Document, test, and verify in Release |
| Verification required | Evidence is outside repository or final archive | Prove before release; do not assume |

## Findings

### F-01 — Mock dependency graph ships in the application target

**Severity:** Blocker

**Evidence:** `ServiceContainer.swift` declares `ServiceContainer.mock()` plus mock implementations for Photos, OCR, extraction, Calendar, Reminders, notifications, and subscriptions in `Sources/DateSnap`. Those implementations grant permissions, return successful synthetic identifiers, return fabricated OCR/event data, and grant Plus. `ServiceContainerKey.defaultValue` is `ServiceContainer.mock()`.

**Risk:** A missing environment injection silently changes the app from real services to always-successful fake behavior. Because the mocks live in the product target, Release contains non-production implementations even though `DateSnapApp` currently injects `.live()` explicitly.

**Required treatment:** **Isolate and replace the fallback.** Move test doubles to `Tests/DateSnapTests/` and preview-only fixtures to Debug-only support. Make the production environment default fail fast during development or use a deliberately unavailable/deny-by-default implementation that cannot report success. Never default subscription access above Starter.

**Exit criteria:** Release source/binary contains no `Mock*Service`, mock event identifiers, fabricated OCR output, or permissive mock container; every production screen receives `.live()` explicitly; tests/previews inject named fixtures.

### F-02 — Settings are mostly ephemeral UI state, not production configuration

**Severity:** Blocker

**Evidence:** `SettingsState` holds plan/billing, privacy, scan-mode, capture-scope, confidence, digest, low-power, reminder-route, sound, and timed-alert values. Searches found no consumers of these settings in `Services/` or `ViewModels/`. The object is constructed fresh in `ContentView`, and most properties are not persisted.

**Risk:** Users can change polished controls and receive confirmation toasts, but behavior does not change and selections reset across launches. This creates deceptive functionality and invalidates QA based on UI state alone.

**Required treatment:** **Replace or remove per setting.** Create an explicit setting-to-consumer ledger. For each setting, either wire it through persisted storage into a real runtime consumer with tests, or remove/disable the control and related copy from Release. Do not persist a setting merely to make the toggle “stick” if no behavior consumes it.

**Exit criteria:** Every production-visible mutable setting has one documented persistence source, one runtime consumer, and a behavior test; unsupported controls are absent.

### F-03 — Automation Settings advertises unimplemented behavior

**Severity:** Blocker

**Evidence:** Visible copy claims opportunistic scans on screenshot capture, “Ready & Listening,” auto-commit over 95% confidence, background listeners, Share Sheet invocation, camera/AirDrop capture scopes, quick extraction prompts, evening digest, and low-power throttling. No corresponding background task, Share extension, service/view-model setting consumer, or smart-save action was found. The real app loads Photos while active and presents user review.

**Risk:** User and App Review expectations materially exceed shipped functionality. Privacy and battery claims become difficult to substantiate.

**Required treatment:** **Remove/reword immediate unsupported claims and controls.** Retain only the real Apple Intelligence toggle backed by `@AppStorage` and verified capability state. Implement additional automation later only through separately scoped work with lifecycle, permissions, entitlement, battery, and QA evidence.

**Exit criteria:** Every Automation Settings claim can be demonstrated on the Release build; no “listening,” background, Share Sheet, smart-save, digest, or scope claim remains without implementation.

### F-04 — Privacy Center contains fabricated metrics and unsupported assurances

**Severity:** Blocker

**Evidence:** Production UI hard-codes “24.8 MB of 50 MB cap,” “18 event snapshots cached,” a 50% usage bar, “AES-256 GCM,” permission status labels, “Strict socket firewall verification,” and “Certified on iOS 18 Local Sandbox Architecture.” No storage measurement/cap, app-level AES-GCM encryption layer, socket firewall, certification source, or live permission audit backs these values in the reviewed code.

**Risk:** These are security/privacy representations, not harmless placeholders. They can mislead users and reviewers and create regulatory or reputational exposure.

**Required treatment:** **Remove or replace immediately.** Compute real counts/size and live authorization states where useful. Describe platform data protection accurately without claiming app-specific AES-GCM unless implemented and verified. Replace firewall/certification assertions with evidence-backed on-device processing language already supported by architecture and network testing.

**Exit criteria:** No hard-coded operational metric or unsupported security/certification claim remains; every displayed status is derived from live state or clearly labeled explanatory copy.

### F-05 — Privacy and security controls are not implemented

**Severity:** High

**Evidence:** `screenshotAutoPurge`, `purgeWindow`, and `faceIDProtection` exist in transient `SettingsState`; no service/view-model consumes them. The manual “Clear Local Scan Cache” and reset actions perform real SwiftData mutations, but automatic purge and biometric protection were not found.

**Risk:** Users may believe sensitive data is automatically deleted or protected by Face ID when it is not.

**Required treatment:** **Remove the controls for immediate release unless implementation is explicitly prioritized.** If retained later, use real retention scheduling and LocalAuthentication gates, persist policy, define failure/recovery behavior, and test relaunch/background paths.

**Exit criteria:** Release shows only privacy controls that produce verified behavior; manual deletion accurately reports failures instead of unconditional success.

### F-06 — Reminder settings and “Active Simulation” are disconnected from scheduling

**Severity:** High

**Evidence:** `SettingsState.timedAlerts`, preset, route, and sound are edited by `ReminderSettingsView`, but no service/view model consumes them. “Active Simulation” uses a static OCT 24 event, hard-coded date text, and configured labels. Sound choices are strings with no audio/haptic implementation.

**Risk:** Users believe reminder defaults and delivery channels affect saved events when actual scheduling uses separate offsets/services.

**Required treatment:** **Remove or implement.** For immediate release, either reduce this screen to controls that feed actual `EventReviewViewModel` defaults and notification scheduling, or remove the route. Rename any retained visual example to “Preview” and derive it from real configured offsets; do not call it active simulation.

**Exit criteria:** Changing a reminder default changes the next saved event’s Calendar/Reminders/local-notification schedule and is covered by tests, or the control is absent.

### F-07 — StoreKit paywalls show hard-coded fallback prices

**Severity:** High

**Evidence:** `PurchaseViewModel.displayPrice` and `monthlyEquivalent` accept display fallbacks. Paywalls supply `$4.99`, `$39.99`, `$8.99`, `$69.99`, `$3.33`, and `$5.83`. If StoreKit loading fails, the fallback is displayed while purchase controls may remain interactable. `SettingsState.planPrice` separately claims `$29.99` annually, conflicting with the configured Plus annual price.

**Risk:** Displayed pricing can be wrong for storefront, tax, product configuration, or price changes. Conflicting prices damage purchase trust and may create App Review problems.

**Required treatment:** **Replace.** Show loading/unavailable state until a real `Product` supplies localized pricing. Disable purchase CTA when the selected product is missing. Remove legacy `SettingsState` plan price/name and centralize product metadata.

**Exit criteria:** Release paywalls never present a purchasable hard-coded price; all price/trial/renewal copy comes from the selected StoreKit product; failure state is explicit.

### F-08 — Sample flyer is intentional production demo content, not a mock service

**Severity:** Retain with verification

**Evidence:** `SampleFlyer` renders an image with a date about 21 days ahead; `ScanViewModel.scanSampleFlyer` sends it through the real scan pipeline. The App Review runbook explicitly directs reviewers to “Try Sample Flyer.”

**Risk:** Removing it would eliminate a useful no-permission reviewer/onboarding path. Its deterministic content could still drift from OCR expectations.

**Required treatment:** **Retain.** Rename/document as demo content if needed, keep it separate from user records through a stable source identifier, and add an end-to-end test that verifies it produces a future review candidate without granting Photos access. Confirm it does not create Calendar/Reminder records without user confirmation.

**Exit criteria:** Release QA proves the sample uses production OCR/extraction and is clearly labeled as a sample.

### F-09 — Debug gallery and sample events are correctly compiled out, but isolation should be verified

**Severity:** Medium

**Evidence:** `ScreenGalleryView` and `DateSnapEvent` sample fixtures are wrapped in `#if DEBUG`; ContentView presents `EmptyView` for `.screenGallery` in Release; Home simulation controls are Debug-only. The modal enum case remains compiled in Release.

**Risk:** Current guards are reasonable, but future references can accidentally leak debug navigation. Debug descriptions also contain feature claims that may drift.

**Required treatment:** **Retain with stronger isolation.** Verify the Release preprocessed source/binary lacks fixture strings and gallery symbols. Consider moving the gallery and fixtures to a Debug-only source directory/target or wrapping the entire route/case consistently.

**Exit criteria:** Release binary scan finds no sample event titles, Stitch IDs, gallery copy, or debug simulation labels.

### F-10 — Silent error suppression can produce fake-success UX

**Severity:** High

**Evidence:** Multiple destructive/persistence/integration paths use `try?`, including SwiftData saves/deletes and Calendar/Reminder cleanup. Privacy Center shows “Scan cache cleared” immediately after `try?` operations. Event review prints and continues when reminder creation fails. Some best-effort OCR/parser fallbacks are legitimate, but side-effect failures are not consistently surfaced.

**Risk:** The UI can state that data was cleared or synced when an operation failed. This is functionally equivalent to a fake feature result.

**Required treatment:** **Replace silent side-effect suppression with typed results.** Keep deliberate parsing fallbacks, but surface persistence/deletion/integration failure and only show success after confirmation. Add privacy-safe structured logging.

**Exit criteria:** Every user-initiated mutation reports confirmed success, partial success, or failure; no destructive action unconditionally toasts success after `try?`.

### F-11 — Release configuration still contains explicit placeholders

**Severity:** Blocker (also tracked by production-readiness audit)

**Evidence:** `YOUR_TEAM_ID` remains in Debug/Release xcconfigs and `ExportOptions-AppStore.plist`; release documentation contains credential-shaped examples. External URLs require live verification.

**Risk:** Signing/export fails or documentation is mistaken for configured credentials.

**Required treatment:** Resolve signing configuration per the production-readiness plan. Keep credential examples clearly parameterized; never commit private keys. Verify privacy/support URLs live.

**Exit criteria:** No placeholder occurs in an evaluated Release setting or export file; documentation variables cannot be mistaken for real secrets.

### F-12 — Source has no explicit TODO markers, but older planning documents contain stale implementation claims

**Severity:** Medium

**Evidence:** No TODO-family markers were found under `Sources/DateSnap`. Older plans still describe prototype mocks/dummy timers and outdated repository structure. `AGENTS.md` describes a placeholder skeleton/pure package despite the current generated project and substantial app.

**Risk:** Agents and release operators may follow stale context, redo completed work, or miss current gaps.

**Required treatment:** Mark historical plans as historical or update their status; refresh `AGENTS.md` separately with owner approval. Do not delete audit history.

**Exit criteria:** Active instructions reflect current structure and link to the latest audits; historical documents are clearly labeled.

## Inventory disposition

| Item | Current location | Classification | Immediate disposition |
|---|---|---|---|
| `ServiceContainer.mock()` | Product target | Isolate | Remove from Release; explicit fixtures only |
| `MockPhotoLibraryService` | Product target | Isolate | Move to test/preview support |
| `MockOCRService` | Product target | Isolate | Move to test/preview support |
| `MockEventExtractionService` | Product target | Isolate | Move to test/preview support |
| `MockCalendarService` | Product target | Isolate | Move to test/preview support |
| `MockReminderService` | Product target | Isolate | Move to test/preview support |
| `MockNotificationService` | Product target | Isolate | Move to test/preview support |
| `MockSubscriptionService` returning Plus | Product target | Remove/isolate | Replace with injectable deny-default fixture |
| Default mock environment container | Product target | Replace | Fail fast or unavailable production default |
| `SampleFlyer` | Product target | Retain | Verify real-pipeline behavior and labeling |
| DEBUG screen gallery | Product target, conditional | Retain/isolate | Binary verification; stronger compile isolation |
| DEBUG sample `DateSnapEvent`s | Product target, conditional | Retain/isolate | Binary verification |
| Home simulation hub | DEBUG conditional | Retain/isolate | Binary verification |
| `SettingsState` plan fields | Product UI state | Remove | Use StoreKit state only |
| Automation mode/scope/digest controls | Product UI | Remove or replace | Immediate removal/reword unless implemented |
| Face ID/auto-purge controls | Product UI | Remove or replace | Do not claim protection/retention without behavior |
| Reminder defaults/routes/sounds | Product UI | Remove or replace | Wire to scheduling or remove |
| Static reminder simulation | Product UI | Remove/reword | Real derived preview only |
| Hard-coded cache metrics | Product UI | Remove/replace | Compute real values or omit |
| AES-256 GCM badge | Product UI | Remove/verify | Use accurate platform-protection copy |
| Firewall/certification claims | Product UI | Remove/reword | Evidence-backed privacy language only |
| Hard-coded StoreKit prices | Product UI | Replace | Localized `Product` values only |
| Parser/model fallback routes | Production algorithms | Retain | These are resilience paths, not mocks; test them |
| Short UI timing delays | Production UI | Retain with review | Animation/navigation timing, not fake processing |

## Immediate remediation plan

### Phase 1 — Stop fake code from entering Release

1. Split production dependency wiring from test/preview fixtures.
2. Move mock service implementations out of `Sources/DateSnap` or compile them only in Debug where previews require them.
3. Replace the environment’s permissive default with a non-successful production-safe dependency strategy.
4. Add a Release-source/binary scan for `Mock`, known sample titles, Stitch IDs, “Simulation Hub,” and mock identifier prefixes.

### Phase 2 — Remove unsupported production claims and controls

1. Build a setting-to-consumer ledger for every `SettingsState` property.
2. Remove/reword unsupported Automation Settings sections immediately; retain the real enhanced-interpretation toggle.
3. Remove fabricated Privacy Center metrics, badges, permission labels, firewall claim, and certification claim.
4. Remove Face ID and automatic purge controls unless real implementations are part of immediate release scope.
5. Remove or reduce Reminder Settings until controls feed actual schedule defaults.
6. Update Help/Review copy anywhere it claims behavior not demonstrated by the Release build.

### Phase 3 — Eliminate production fallbacks that misrepresent state

1. Remove hard-coded paywall price fallbacks and disable purchase while products are missing.
2. Replace silent mutation `try?` paths with typed results and accurate success/partial/failure UX.
3. Replace hard-coded status/usage displays with live data or omit them.
4. Resolve signing placeholders through the existing production-readiness plan.

### Phase 4 — Preserve legitimate demos and resiliency

1. Keep `SampleFlyer` as explicit demo content using the real pipeline.
2. Keep deterministic/rules-only intelligence and parser fallbacks; they are production resilience, not mocks.
3. Keep animation/navigation sleeps only where they are tied to UX transitions, not used to imitate work.
4. Add tests distinguishing intentional demo/fallback paths from production service substitution.

### Phase 5 — Prove cleanup completeness

1. Add a scripted repository scan with an allowlist for tests, previews, historical docs, and the intentional sample flyer.
2. Build/inspect a Release archive, not just Debug source.
3. Exercise every visible Settings control and record its observable downstream effect.
4. Run offline and failure-injection tests for StoreKit, SwiftData, Calendar, Reminders, notifications, Photos, OCR, and Foundation Models.
5. Require owner signoff for every allowlisted mock/sample/fallback.

## Verification matrix

| Area | Verification step | Evidence required | Pass criteria | Blocking if failed |
|---|---|---|---|---|
| Product-target mocks | Search source and Release symbols/strings | Scan output and archive | No mock service or mock success identifier in Release | Yes |
| Dependency injection | Launch every production root/sheet | Integration result | All screens use live container; missing injection cannot succeed | Yes |
| Settings behavior | Change every visible setting and relaunch | Setting-to-consumer ledger and test | Persisted value changes documented runtime behavior | Yes |
| Automation claims | Demonstrate each retained claim | Physical-device video/logs | UI language exactly matches behavior | Yes |
| Privacy metrics | Compare UI to measured storage/state | Measurement code/test | Values are live or absent | Yes |
| Security claims | Trace each claim to implementation/platform fact | Security review | No unsupported encryption/firewall/certification claim | Yes |
| Permission audit | Change system permissions while app runs | QA matrix | UI reflects actual authorization status | Yes |
| Data deletion | Inject SwiftData failure and perform clear/reset | Result/error evidence | No false success; partial/failure is surfaced | Yes |
| Reminder defaults | Save event after changing each retained setting | EventKit/notification inspection | Actual schedule matches configuration | Yes |
| StoreKit prices | Test unloaded/error/all storefront products | Screenshots and StoreKit logs | No hard-coded purchasable price; missing product disables CTA | Yes |
| Sample flyer | Run without Photos permission | End-to-end result | Real pipeline yields review candidate; no automatic external write | No |
| Debug fixtures | Inspect Release archive strings/symbols | Scan report | Gallery/sample fixture strings absent | Yes |
| TODO markers | Run source scan | Scan output | No unowned actionable marker in production source | No |
| Silent fallbacks | Review user mutations and inject failures | Failure tests | All mutations produce accurate outcomes | Yes |
| Signing placeholders | Evaluate Release settings/export | Settings/export record | No placeholder in effective release path | Yes |

## Confidence and limitations

This audit provides high confidence for repository-visible Swift source and configuration patterns, but it cannot alone prove that App Store Connect products, external URLs, platform data-protection behavior, or the final optimized binary match the repository. Final confidence requires:

- a clean, frozen candidate;
- Release archive inspection;
- App Store/TestFlight configuration verification;
- physical-device execution of every retained Settings feature;
- failure injection for external and persistence services;
- a reviewed allowlist documenting every intentional sample, fallback, and Debug fixture.

The cleanup should not pursue a literal zero occurrence of words such as “sample” or “fallback.” The correct standard is: no non-production dependency can execute in Release, no visible feature pretends to work, no operational/security value is fabricated, and every intentional demo or resilience path is explicitly owned and tested.

## Release recommendation

Treat F-01 through F-04, F-07, and the Release portion of F-11 as hard pre-release blockers. Treat F-05, F-06, and F-10 as required fixes unless the affected UI is removed for launch. Retain F-08 and the legitimate algorithmic fallbacks. Verify F-09 in the final archive. Address stale documentation in F-12 without deleting historical audit context.
