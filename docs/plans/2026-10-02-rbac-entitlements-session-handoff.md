# Session handoff — RBAC / subscription entitlements remediation

Started: 2026-10-02. Status: **discovery complete, no code changes made yet.**

Read in this order to resume:

1. This file (state, blockers, commands).
2. `docs/plans/2026-10-02-rbac-entitlements-implementation-plan.md` — the work to perform.
3. `docs/audits/2026-10-02-rbac-and-subscription-entitlements-audit.md` — findings F-01..F-09 and the verification matrix.

## User's instructions (verbatim intent)

- Review the plan above, perform its updates, then generate and save a completion report in `docs/`.
  In chat, give only a small summary.
- "Please merge into main once all the features have landed and are committed."
- Installed iOS agent skills from `https://github.com/twostraws/swift-agent-skills` (see below).

## Definition of Done

- Every finding in the audit fixed or deferred with written reason + owner; each fix maps to ≥1 atomic
  commit on a feature branch.
- Debug and Release builds succeed with **no new warnings**; Swift 6 strict concurrency
  (`SWIFT_STRICT_CONCURRENCY = complete`) stays satisfied.
- Entitlement/role checks go through **one authoritative layer**; UI does not duplicate them.
  No hardcoded unlocks, debug bypasses, or secrets.
- StoreKit transactions verified; expiration, revocation, refund, restore handled; free/paid behavior
  tested against `DateSnap.storekit` (wired into the app scheme).
- All existing + new tests pass. New tests cover: free user, active subscriber, expired subscriber,
  revoked subscriber, restored purchase, denied permission.
- `PrivacyInfo.xcprivacy` re-checked (no data collection + only `UserDefaults` required-reason API);
  `Info.plist` permission strings match behavior; `DateSnap.entitlements` matches used capabilities.
- Working tree clean, all commits on the feature branch; docs/runbooks reflect behavior changes;
  completion report at `docs/audits/2026-10-02-rbac-entitlements-completion-report.md` with a
  findings-to-commit table, test results, deviations, and remaining risks.

## Intended atomic commits (in order, each staging explicit audit-related paths only)

1. `feat(entitlements): centralize verified feature access`
2. `fix(storekit): fail closed on unresolved entitlements`
3. `fix(entitlements): enforce protected scan operations`
4. `fix(entitlements): guard premium deadline reminders`
5. `fix(subscriptions): normalize catalog and restore state`
6. `docs(entitlements): report audit remediation`

**Do not** stage the concurrent production-readiness/settings edits already in the tree (below).
The build-infra fix in "Blocker" is required by the DoD — keep it as its own clearly-scoped change.

## Repo state

- Branch: `feature/rbac-entitlements`. Recent commits (newest first):
  `f0e4844 docs(dev): remove stale mock requirements`, `e3311a8 build(release): gate non-production
  content`, `a625097 refactor(di): remove production mock services`, `11f48f7`, `172c7ee`, `f6bc400`,
  `5ef7d77`, `a5ecd59`, `718d98e docs(entitlements): audit paid feature enforcement`, `e10b2ec`,
  `0c6d14b`, `38491f2`, `5b047a0`, `5866c78`, `b800ddb`.

- **DIRTY TREE — concurrent work in progress, do NOT stage or revert these:**
  - staged: `Sources/DateSnap/Models/SettingsState.swift`,
    `Sources/DateSnap/Views/AutomationSettingsView.swift`,
    `Sources/DateSnap/Views/ReminderSettingsView.swift`,
    new `docs/plans/2026-10-02-rbac-entitlements-implementation-plan.md`
  - unstaged modified: `Sources/DateSnap/Services/SavedEventActions.swift`,
    `Sources/DateSnap/Views/HelpFeedbackView.swift`, `Sources/DateSnap/Views/PrivacyCenterView.swift`,
    `Sources/DateSnap/Views/SettingsHubView.swift`
  - new untracked: `.opencode/skills/*` (installed this session), this handoff file.

- Layout: `Sources/DateSnap/{Models,Services,Views,ViewModels,Theme,Persistence}`; tests in
  `Tests/DateSnapTests/*.swift` (9 files); pure SwiftPM `Package.swift` **and** `DateSnap.xcodeproj`
  generated from `project.yml` (XcodeGen 2.46.0 at `/opt/homebrew/bin/xcodegen`); `Config/*.xcconfig`;
  `Info.plist`, `PrivacyInfo.xcprivacy`, `DateSnap.entitlements`, `DateSnap.storekit`;
  `docs/{audits,plans,prompts,runbooks}`; `HANDOFF.md` (Wave 2 release checklist — do not overwrite);
  `AGENTS.md`.
- `project.yml`: SWIFT_VERSION 6.0, `SWIFT_APPROACHABLE_CONCURRENCY YES`,
  `SWIFT_STRICT_CONCURRENCY complete`; app target `DateSnap` (INFOPLIST_FILE Info.plist,
  CODE_SIGN_ENTITLEMENTS DateSnap.entitlements, scheme `storeKitConfiguration DateSnap.storekit`,
  testTargets DateSnapTests); test target `DateSnapTests` (bundle.unit-test, deps target DateSnap,
  PRODUCT_BUNDLE_IDENTIFIER com.datesnap.app.tests, GENERATE_INFOPLIST_FILE YES).
  `configFiles` Debug/Release → `Config/DateSnap-{Debug,Release}.xcconfig` applied at **PROJECT** level.

## BLOCKER — baseline build fails (root cause found, fix not yet applied)

Command used (background):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DateSnap.xcodeproj -scheme DateSnap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /var/folders/z3/s3tm6rdx1kzdddzgh_2d6dpm0000gn/T/opencode/rbac/dd \
  build-for-testing
```

Log: `/var/folders/z3/s3tm6rdx1kzdddzgh_2d6dpm0000gn/T/opencode/rbac/baseline-build.log`
Evidence dir: `/var/folders/z3/s3tm6rdx1kzdddzgh_2d6dpm0000gn/T/opencode/rbac`

Result: 4 errors — `Multiple commands produce '.../Debug-iphonesimulator/DateSnap.swiftmodule/*'`
(`.swiftsourceinfo`, `.abi.json`, `.swiftdoc`, `.swiftmodule`). Both `Target 'DateSnap'` and
`Target 'DateSnapTests'` emit a copy command for `DateSnap.abi.json` etc.

**Root cause:** `Config/DateSnap-Base.xcconfig` sets `PRODUCT_NAME = DateSnap`, and because
`project.yml` applies those xcconfigs at the project level, the `DateSnapTests` target inherits
`PRODUCT_NAME = DateSnap` → module name collides with the app module. Verified:
- `DateSnap.xcodeproj/project.pbxproj` `DateSnapTests` XCBuildConfiguration blocks (~lines 546–574)
  set only `BUNDLE_LOADER`, `GENERATE_INFOPLIST_FILE YES`,
  `PRODUCT_BUNDLE_IDENTIFIER com.datesnap.app.tests`, `SDKROOT = iphoneos`,
  `TEST_HOST = $(BUILT_PRODUCTS_DIR)/DateSnap.app/DateSnap` — **no PRODUCT_NAME override**.
- pbxproj Sources phases are correct (app phase has all app files incl. `ScanViewModel.swift:511`;
  test phase has only the 9 test files incl. `AdvisorTests.swift:531`).

**Fix:** add `PRODUCT_NAME: "$(TARGET_NAME)"` (or `DateSnapTests`) to the `DateSnapTests`
target `settings.base` in `project.yml`, run `xcodegen generate --spec project.yml`, then confirm with
`xcodebuild -showBuildSettings -project DateSnap.xcodeproj -target DateSnapTests -configuration Debug | grep PRODUCT_NAME`.

## Toolchain / environment

- `xcodebuild` is **not on PATH** (`xcode-select` → CommandLineTools). Always prefix
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Xcode 27.0 (27A266a), Apple Swift 6.4 (`swift --version` confirms). `swift build` will fail for
  iOS-only APIs — use `xcodebuild`.
- Simulators: `iPhone 17` (Booted, iOS 27.0), iPhone 18 Pro, iPad Pro 13-inch (M5).
- `xcodebuild -list -project DateSnap.xcodeproj` → targets `DateSnap`, `DateSnapTests`; configs
  `Debug`, `Release`; scheme `DateSnap`.
- Prior verification (`docs/audits/2026-10-02-production-readiness-verification.md`): 43 tests
  (41 passed, 0 failed, 2 skipped = opt-in `DATESNAP_EVAL_LIVE=1`); XcodeGen no-diff regeneration;
  four StoreKit IDs match between `SubscriptionService` and `DateSnap.storekit`; no URLSession/
  telemetry; UserDefaults CA92.1; empty entitlements dict.
- Release runbook: `docs/runbooks/RELEASE.md`.
- StoreKit product IDs (also at `DateSnap.storekit` lines 97/127/152/177):
  `com.datesnap.plus.monthly`, `com.datesnap.plus.annual`, `com.datesnap.premium.monthly`,
  `com.datesnap.premium.annual`.

## Skills installed this session (`.opencode/skills/`, from twostraws/Swift-Agent-Skills)

- `swiftui-pro` — `.opencode/skills/swiftui-pro/SKILL.md` + `references/`
- `swift-testing-pro` — `.opencode/skills/swift-testing-pro/SKILL.md` + `references/`
- `swift-concurrency-pro` — `.opencode/skills/swift-concurrency-pro/SKILL.md` + `references/`

Each also carries `LICENSE` (MIT) and `UPSTREAM-README.md`. Reviewed before install: MIT, human-authored
(Paul Hudson), no exec/URL-fetch instructions. **Not visible in an already-running session's
`<available_skills>`** (loaded at session start) — a new session will pick them up. There is **no
StoreKit skill** in that directory; StoreKit work is covered by the audit/plan docs.
Not installed (irrelevant): accessibility, App Intents, widgets, background execution, App Store/ASO,
Figma, simulator, architecture, and duplicate SwiftUI/SwiftData/Testing skills from other authors.

## Task list

1. ~~Read audit doc and explore codebase structure~~ (done — see below).
2. Fix the build blocker (`PRODUCT_NAME` on `DateSnapTests`) and get a green baseline build+test.
3. Task 1: `FeatureAccessPolicy`, product catalog, entitlement resolver + tests.
4. Task 2: StoreKit service + lifecycle snapshot propagation (launch / transaction update /
   purchase / restore / scene-active).
5. Task 3: Secure scan operation boundaries (document import).
6. Task 4: Guard deadline reminders + denied-permission paths.
7. Task 5: Purchase/restore + plan presentation catalog (kill substring mapping).
8. Task 6: Docs/privacy check + completion report at
   `docs/audits/2026-10-02-rbac-entitlements-completion-report.md`.
9. Full tests + Debug/Release builds + clean-tree verification.
10. Commit the six atomic commits, then **merge `feature/rbac-entitlements` into `main`**.

## Audit findings (F-01..F-09) — one line each

The model is local subscription feature entitlement; there is **no accounts/RBAC**.

- **F-01 High** — `HomeEmptyStateView` gates `.documentImport` in the UI, but the file-import
  completion calls `ScanViewModel.scanDocument(at:modelContext:)` with **no entitlement dependency**.
- **F-02 High** — `EventReviewViewModel.commitEvent` creates a deadline reminder when
  `deadlineReminderEnabled && deadlineReminderDate != nil` with **no policy re-check**; the view passes
  a plain `Bool`.
- **F-03 Medium** — access logic split across `AppState.isEntitled`, `isPlusMember`/`isPremiumMember`,
  `SubscriptionTier.includes`, `IntelligenceUsagePolicy`; `HomeViewModel.triageLikelyEvents` takes a
  **caller-supplied tier**.
- **F-04 Medium** — only a tier is modeled; cannot distinguish loading / StoreKit-unavailable /
  verification-failure / revoked; scene-active refresh does **not** refresh StoreKit.
- **F-05 Medium** — product-ID→tier mapping duplicated, incl.
  `productID.contains("premium")` substring inference in `ManagePlanView`.
- **F-06 Medium** — verification errors silently discarded (empty `catch` in `listenForTransactions`
  and `continue` in the current-entitlements loop).
- **F-07 High** — tests validate policy **tables**, not protected **actions**.
- **F-08 Medium** — permissive mocks (`MockSubscriptionService` always Plus, `ServiceContainer.mock()`).
  **Already removed** by commits `a625097`/`f0e4844`; test doubles still need to be added, deny-by-default.
- **F-09 Informational** — no identity/social authorization exists; **do not** add
  admin/host/member/guest to `SubscriptionTier`.

Tier hierarchy: Starter=0, Plus=1, Premium=2.
Feature matrix: `automaticScreenshotDetection`=plus, `likelyEventTriage`=plus,
`documentImport`=premium, `duplicateClusters`=premium, `advancedReminderPlans`=premium.

Positive controls already present: `checkVerified` accepts only `.verified`;
`Transaction.currentEntitlements` excludes revoked; initial tier Starter (fail-closed);
`AppState.subscriptionTier` is `private(set)`; `PremiumFeature` is a closed enum;
`IntelligenceUsagePolicy` returns 0 when tier lacks feature; DEBUG-only screen simulation.
`ServiceContainer` env key defaults to `nil` and `EnvironmentValues.services` does
`preconditionFailure` when nil → DI already fails closed.

Release recommendation from the audit: F-01/F-02/F-07 required pre-release; F-03..F-06 and F-08
required hardening unless the risk is accepted in writing.

## Verification matrix the tests must satisfy

Exhaustive tier×feature test; document import per tier (Premium only); deadline reminder
force-enabled per tier (Premium only); automatic screenshot detection as a **gated use case**
(Starter denied when invoked directly); triage without caller-supplied tier; duplicate clusters
gated; cold-launch "checking" denies paid; purchase/restore update snapshot; expiration/revocation
denies without relaunch; unknown product grants nothing; verification failure denied + safe
diagnostic; missing dependency = build failure or deny-by-default; product catalog parity across
code / `DateSnap.storekit` / App Store Connect; no social roles in `SubscriptionTier`.

## Key source knowledge (paths + line anchors)

- `Sources/DateSnap/Services/Advisors/FeatureEntitlements.swift` (51 lines) —
  `public enum PremiumFeature: String, CaseIterable, Sendable` (5 cases) with `requiredTier`
  (autoDetection+triage→plus; documentImport+duplicateClusters+advancedReminderPlans→premium) and
  `upgradeReason`; `extension SubscriptionTier { private var rank; func includes(_:) -> Bool }`.
- `Sources/DateSnap/Services/SubscriptionService.swift` (185 lines) —
  `SubscriptionTier: String, CaseIterable, Identifiable, Sendable` (starter/plus/premium).
  `@MainActor public protocol SubscriptionServiceProtocol: Sendable { currentTier; isSubscribed;
  fetchProducts() async throws -> [Product]; purchase(product:) async throws -> SubscriptionTier;
  restorePurchases() async throws -> SubscriptionTier; updateCustomerProductStatus() async }`.
  `@MainActor public final class SubscriptionService: ObservableObject, SubscriptionServiceProtocol`:
  `static let shared`, `@Published private(set) currentTier = .starter`, `availableProducts`,
  `purchasedProductIDs`, `isLoading`, `isSubscribed`, `static let productIdentifiers: Set<String>`
  (the 4 IDs), `updateListenerTask` from `listenForTransactions()` (detached Task over
  `Transaction.updates`, **empty catch = F-06**), init kicks `updateCustomerProductStatus()` +
  `fetchProducts()`, `deinit` cancels. `purchase` → `.success(verification)` → `checkVerified` →
  `updateCustomerProductStatus()` → `transaction.finish()` → returns `currentTier`;
  `.userCancelled`→purchaseCancelled, `.pending`→purchasePending, `@unknown default`.
  `restorePurchases` → `AppStore.sync()` → `updateCustomerProductStatus()`; error→verificationFailed.
  `updateCustomerProductStatus()` loops `Transaction.currentEntitlements`, `checkVerified`,
  skips `revocationDate != nil`, `catch { continue }`, then hardcodes premium IDs → `.premium`,
  plus IDs → `.plus`, else `.starter` (**F-05**). `nonisolated static checkVerified` throws
  `DateSnapError.subscription(.verificationFailed)` on `.unverified`.
- `Sources/DateSnap/Models/AppState.swift` (113 lines) — `@MainActor final class AppState:
  ObservableObject`; `@Published var selectedTab`, `activeModal: AppModalScreen?`
  (premiumPaywall, plusPaywall, calendarPermissionDenied, notificationPermissionDenied,
  noDatesFound, savedEventDetail, eventReviewEdit, reminderScheduleEditor, recentScreenshots,
  screenGallery); `@Published private(set) var subscriptionTier = .starter`; `isPlusMember`
  (= != .starter), `isPremiumMember` (= == .premium), `isEntitled(to:)` (= `tier.includes`);
  `tierSubscription: AnyCancellable?`; `bind(subscription:)` sets tier then, if
  `as? SubscriptionService`, sinks `live.$currentTier` on main; `showToast`.
- `Sources/DateSnap/Services/ServiceContainer.swift` (78 lines) — `public final class
  ServiceContainer: ObservableObject, @unchecked Sendable` with photoLibrary/ocr/eventExtraction/
  calendar/reminders/notifications/subscription/understanding; `@MainActor static func live()`
  uses `SubscriptionService.shared` + `IntelligenceComposition.liveUnderstanding()`;
  **`ServiceContainer.mock()` no longer exists** (removed in `a625097`). Env key
  `defaultValue: ServiceContainer? = nil`; `EnvironmentValues.services` getter does
  `preconditionFailure("ServiceContainer must be injected at the application or preview root.")`.
- `Sources/DateSnap/ViewModels/ScanViewModel.swift` (313 lines) — `@MainActor public final class
  ScanViewModel: ObservableObject`; `init(services: ServiceContainer)`; `ScanStage` enum
  (idle, fetchingImage, processingOCR, extractingEvents, interpreting, complete(candidates:),
  noDatesFound(rawText:), alreadySaved(count:), failed(String)) with custom `==`; @Published
  `stage, rawOcrText, ocrConfidence, extractedCandidates, currentProcessingImage, isProcessing,
  progressDetail, understandingByCandidateID, lastResult`. Public entry points: `scanAsset`,
  `scanImage`, `scanImageData`, `scanSampleFlyer`, and **`scanDocument(at url: URL, modelContext:)`**
  (sets `isProcessing`, `stage = .fetchingImage`, `startAccessingSecurityScopedResource`, PDF →
  `scanPages` else `Data(contentsOf:)` → `scanImageData`). Private `scanPages`,
  `recognizeWithRetry`, `skipInterpretation`, `combine`, `reset`. **No entitlement dependency (F-01).**
- `Sources/DateSnap/ViewModels/HomeViewModel.swift` (168 lines) — `init(services:)` calls
  `refreshStatus()` + `startObservingPhotoLibrary()`; `refreshStatus()` sets
  `currentSubscriptionTier = subscriptionService.currentTier`; `ensurePhotoAccess`,
  `loadRecentScreenshots(limit:)`; **`triageLikelyEvents(scannedIDs: Set<String>, tier: SubscriptionTier)`**
  (line ~139) uses `IntelligenceUsagePolicy().consume(.likelyEventTriage, count:tier:)` then
  `PhotoCandidateRanker.isLikelyEvent` — **caller-supplied tier = F-03**.
- `Sources/DateSnap/ViewModels/EventReviewViewModel.swift` (379 lines) — `init(candidate:services:
  sourceImage:)`; **`commitEvent(modelContext:) async -> Bool`** sequence: `applyEdits` →
  calendar create/update (catch `.accessDenied` → `calendarAccessDenied = true`, return false) →
  reminders create/update (catch → `print("Notice: Reminder creation skipped or denied: …")`) →
  **step 2b at lines 309–315:**
  ```swift
  var deadlineReminderId = existing?.deadlineReminderId
  if deadlineReminderEnabled, deadlineReminderId == nil, let due = deadlineReminderDate {
      deadlineReminderId = try? await reminderService.createDeadlineReminder(
          title: "RSVP: …", due: due, url: candidate.rsvpUrl, list: selectedReminderList)
  }
  ```
  (**F-02 — no policy check**) → `removePendingNotifications` + `scheduleAlerts`
  (sets `notificationsSkipped` on throw) → persist record incl. `record.deadlineReminderId`,
  status `.saved`. `EventReviewViewModel+Interpretation.swift` exposes
  `deadlineReminderDate: Date? { reminderPlan.deadlineReminder }`.
- `Sources/DateSnap/ViewModels/PurchaseViewModel.swift` (114 lines) — `enum Plan: Sendable { case
  plus, premium; monthlyID/annualID/tier }` (**hardcoded IDs = F-05**); optional
  `subscription: SubscriptionServiceProtocol?`; `attach(_:) async` loads products;
  `currentTier = subscription?.currentTier ?? .starter`; `purchase(_:annual:) async -> SubscriptionTier?`;
  `restore() async -> SubscriptionTier?`. Also `enum DateSnapLinks` (privacy/support/terms URLs).
- `Sources/DateSnap/Views/ManagePlanView.swift` — **nested `struct EntitlementSnapshot
  { productID, expirationDate, willAutoRenew, isAnnual }` — NAME COLLISION with the new model;
  rename or namespace it.** `tier = appState.subscriptionTier`;
  `refreshEntitlement()` loops `Transaction.currentEntitlements` (verified, no revocation,
  autoRenewable, latest expiration) then
  `purchases.product(latest.productID.contains("premium") ? .premium : .plus, annual:
  latest.productID.hasSuffix(".annual"))` (**F-05 substring**); `.task { await
  purchases.attach(services.subscription); await refreshEntitlement() }`;
  onChange of `appState.subscriptionTier`; restore ~line 322
  (`restored == .starter ? "No active subscription found to restore" : "✓ … restored"`).
- `Sources/DateSnap/Views/HomeEmptyStateView.swift` (693 lines) —
  - `newScreenshots` computed (line ~25): `guard appState.isEntitled(to: .likelyEventTriage) else
    { return unscanned }` else `PhotoCandidateRanker.rank(...)`.
  - Membership pill (lines ~55–75): `isPremiumMember/isPlusMember` → paywall/toast; label
    `PREMIUM/PLUS/FREE`.
  - **Import PDF or File button (lines ~295–318):** `if appState.isEntitled(to: .documentImport)
    { showFileImporter = true } else { appState.activeModal = .premiumPaywall }`; icon
    `appState.isPremiumMember ? "doc.text.viewfinder" : "lock.fill"`; `PREMIUM` badge;
    `.accessibilityHint(...)`; `.disabled(scanViewModel.isProcessing)`.
  - `autoDetectedScreenshotsCard` (line ~532): `if appState.isEntitled(to: .automaticScreenshotDetection)
    && photosAuthorized && !newScreenshots.isEmpty { … }`; inside `.task(id:)` calls
    `homeViewModel.triageLikelyEvents(scannedIDs: …, tier: appState.subscriptionTier)` when
    `isEntitled(to: .likelyEventTriage)`; `else if !appState.isEntitled(to: .automaticScreenshotDetection)`
    shows Plus paywall button.
  - `scanRecentScreenshots()` (line ~520) is the **user-initiated free flow** →
    `homeViewModel.ensurePhotoAccess()` then `loadRecentScreenshots(limit: 30)` + modal
    `.recentScreenshots`. Do **not** gate this — gate automatic detection separately.
- `Sources/DateSnap/Views/HistoryArchiveView.swift` (432 lines) — `duplicateIDs` computed property
  `guard appState.isEntitled(to: .duplicateClusters) else { return [] }` then builds
  `EventSimilarityService.Entry` list → `EventSimilarityService.clusters(entries)` (gated only in the
  view today — centralize behind a gated operation). Has `SmartFilter` enum (upcoming, rsvpDue,
  repeating, duplicates), `filteredEvents`, `actions = SavedEventActions(services:modelContext:)`.
- `Sources/DateSnap/Services/Intelligence/IntelligenceUsagePolicy.swift` (43 lines) —
  `public struct IntelligenceUsagePolicy: Sendable`; `init(defaultsSuiteName: String? = nil)`;
  `static func dailyLimit(for feature:tier:) -> Int` (0 when `!tier.includes(feature)`;
  likelyEventTriage → 120 premium / 30 else; default `.max`); `consume(_:count:tier:now:)`.
- `Sources/DateSnap/ContentView.swift` (204 lines) — `@StateObject appState/settingsState/
  scanViewModel/homeViewModel` (`init(services:)` creates the two VMs); sheet on
  `appState.activeModal` re-injecting `.environmentObject(...)` and `\.services`;
  `.onAppear { appState.bind(subscription: services.subscription); openPendingDeepLink() }`;
  **`.onChange(of: scenePhase) { if phase == .active { homeViewModel.refreshStatus() } }` —
  no StoreKit refresh yet (F-04).**
- `Sources/DateSnap/DateSnap.swift` (21 lines) — `@main struct DateSnapApp: App {
  @StateObject private var services = ServiceContainer.live() }`;
  `.modelContainer(for: [UserSettings, ScannedAsset, EventCandidate, SavedEvent, InterpretationRecord])`.
- Other views — `PlusPaywallView`/`PremiumPaywallView` `restore()` at ~336/~334 calling
  `purchases.restore()`; `InterpretationReviewViews.swift` takes `isEntitledToDeadlineReminders` /
  `isEntitledToReminderPlans` Bools (lines 257/298/352/374);
  `EventReviewEditView.swift` lines 383, 389–391 pass
  `isEntitledToReminderPlans: appState.isEntitled(to: .advancedReminderPlans)`,
  `deadlineReminderDate: viewModel.deadlineReminderDate`,
  `deadlineReminderEnabled: $viewModel.deadlineReminderEnabled`,
  `isEntitledToDeadlineReminders: appState.isEntitled(to: .advancedReminderPlans)`;
  `SettingsHubView.swift` lines 52/96/215–216 switch on `appState.subscriptionTier` /
  `displayName` / `== .starter ? "Upgrade for automatic detection & PDF import" : "View renewal & billing"`.
- `Sources/DateSnap/Services/ReminderService.swift` — protocol line 84 and impl line 179:
  `func createDeadlineReminder(title:due:url:list:) async throws -> String`
  (`list: EKCalendar? = nil`). `SavedEventActions.swift:82` iterates
  `saved.externalReminderIds + [saved.deadlineReminderId].compactMap { $0 }` for deletion.
- Tests — `Tests/DateSnapTests/AdvisorTests.swift` has `@Suite("Cross-service advisors")` with an
  `entitlements()` test over `SubscriptionTier.*.includes(PremiumFeature)`, plus
  `IntelligenceUsagePolicyTests` using
  `defaultsSuiteName: "datesnap.tests.usage.\(UUID().uuidString)"`. **No
  `MockSubscriptionService` and no `ServiceContainer.mock()` anywhere in `Tests/`** (greps are
  empty) — F-08's permissive mocks are gone, but deny-by-default test doubles still must be added.
  There are currently **no stubs for `PhotoLibraryServiceProtocol`/`OCRServiceProtocol`/etc. in the
  test target**, so building `ServiceContainer` for view-model tests needs new doubles.
- UI change rule: read `datesnap-design-system-updated.md` before any UI edit; map the CSS-variable
  tokens to SwiftUI (dark navy glassmorphism, bg `#050816`, primary `#7CFFEA`, accent `#FF4FB3`);
  min 44pt touch targets; confidence states need icon + label + color, never color alone;
  no external dependencies; Swift 6.4 + `ApproachableConcurrency`.

## Design decided for the implementation (not yet written)

- New pure types in `Sources/DateSnap/Services/Advisors/FeatureEntitlements.swift` (or a sibling file):
  - `EntitlementResolutionState`: `.checking`, `.verified`, `.unverified`, `.unavailable`.
  - `EntitlementProvenance`: `.launch`, `.transactionUpdate`, `.purchase`, `.restore`,
    `.sceneActivation`.
  - `EntitlementSnapshot { tier, state, evaluatedAt, provenance }` (Sendable, Equatable).
  - `FeatureAccessDecision` = `.allow` / `.deny(reason)` where reason is typed
    (`.requiresTier(SubscriptionTier)`, `.checkingEntitlements`, `.unverified`, `.unavailable`).
  - `FeatureAccessPolicy.decision(for:snapshot:)` — the single authoritative layer.
  - `EntitlementProviding` protocol (`@MainActor`): `var entitlementSnapshot: EntitlementSnapshot`
    + `func refreshEntitlements(_ provenance:) async`.
  - `SubscriptionProductID` (raw values = the 4 StoreKit IDs) with `tier` / `isAnnual`, plus
    `SubscriptionCatalog.tier(forProductID:) -> SubscriptionTier?` (**exact match, nil for unknown**)
    and `productIdentifiers`.
  - `EntitlementResolver.resolve(...)` — pure; deny-by-default.
- **Deny-by-default rule for unresolved states:** paid features are allowed only when
  `state == .verified && snapshot.tier.includes(feature)`. `.checking` / `.unverified` /
  `.unavailable` deny all paid features (per the audit's "model checking/unverified/unavailable
  separately, deny by default"). Since every `PremiumFeature` requires plus/premium, unresolved
  states deny everything.
- **Verification failures:** increment a published `verificationFailureCount` diagnostic in both
  `listenForTransactions` and `updateCustomerProductStatus`; a failure during a resolution pass sets
  that pass's state to `.unverified`. Never log transaction/user data — generic counts/state only.
- **Rename** `ManagePlanView.EntitlementSnapshot` (nested) to avoid the collision, e.g.
  `StoreKitRenewalInfo`.
- Enforcement points: `ScanViewModel.scanDocument` (F-01), `EventReviewViewModel.commitEvent`
  step 2b (F-02), `HomeViewModel.triageLikelyEvents(scannedIDs:)` — drop the `tier:` parameter (F-03),
  a new gated automatic-detection use case on `HomeViewModel` (not `loadRecentScreenshots`),
  duplicate clusters behind a gated operation called by `HistoryArchiveView` (F-03/F-07),
  scene-active `services.subscription.refreshEntitlements(.sceneActivation)` in `ContentView` (F-04).
- Presentation: expose checking-vs-Starter at least in the `HomeEmptyStateView` membership pill,
  `SettingsHubView`, and `ManagePlanView` plan name.
- Tests: pure policy/catalog/resolver tests + view-model direct-invocation tests with deny-by-default
  stubs; record limitation if StoreKitTest is unavailable in this environment.
