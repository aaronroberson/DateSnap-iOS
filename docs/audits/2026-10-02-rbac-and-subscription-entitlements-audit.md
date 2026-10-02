# DateSnap RBAC and Subscription Entitlements Audit

Date: 2026-10-02

## Scope and terminology

This audit reviews repository-visible authorization, subscription-tier mapping, premium feature gating, StoreKit entitlement resolution, and related tests. DateSnap currently has no user accounts, shared resources, server API, ownership model, or multi-user roles. It therefore does **not** currently implement role-based access control (RBAC) in the conventional sense. Its present authorization model is local subscription-based feature entitlement control.

The future possibilities of hosted events, invitations, RSVPs, comments, planning, group messaging, social graphs, and third-party integrations inform the modularity recommendations, but are explicitly out of scope for immediate implementation. The immediate plan protects the existing Starter/Plus/Premium feature set without inventing a backend, account system, or social-role schema.

## Audit outcome

**Needs remediation before production subscription enforcement can be considered reliable.** The tier matrix and cryptographic StoreKit verification are sound foundations, but premium access is not consistently enforced at operation boundaries. Several features rely on SwiftUI visibility/button checks, which are useful UX controls but are not sufficient authorization controls.

This is primarily a revenue-entitlement correctness risk in the current single-user, on-device product. It is not presently a cross-user data exposure risk because the repository contains no shared-user data plane.

## Inputs reviewed

### Entitlements and purchasing

- `Sources/DateSnap/Services/Advisors/FeatureEntitlements.swift`
- `Sources/DateSnap/Services/SubscriptionService.swift`
- `Sources/DateSnap/Services/Intelligence/IntelligenceUsagePolicy.swift`
- `Sources/DateSnap/ViewModels/PurchaseViewModel.swift`
- `Sources/DateSnap/Views/ManagePlanView.swift` (search-based review of entitlement handling)
- `DateSnap.storekit`

### State and dependency wiring

- `Sources/DateSnap/DateSnap.swift`
- `Sources/DateSnap/ContentView.swift`
- `Sources/DateSnap/Models/AppState.swift`
- `Sources/DateSnap/Models/SettingsState.swift`
- `Sources/DateSnap/Services/ServiceContainer.swift`
- `Sources/DateSnap/ViewModels/HomeViewModel.swift`

### Gated feature paths

- `Sources/DateSnap/Views/HomeEmptyStateView.swift`
- `Sources/DateSnap/ViewModels/ScanViewModel.swift`
- `Sources/DateSnap/Views/HistoryArchiveView.swift`
- `Sources/DateSnap/Views/EventReviewEditView.swift`
- `Sources/DateSnap/Views/InterpretationReviewViews.swift`
- `Sources/DateSnap/ViewModels/EventReviewViewModel.swift`
- `Sources/DateSnap/ViewModels/EventReviewViewModel+Interpretation.swift`
- `Sources/DateSnap/Services/Advisors/ReminderStrategyService.swift`
- `Sources/DateSnap/Services/Advisors/EventSimilarityService.swift` (usage/search review)

### Tests

- `Tests/DateSnapTests/AdvisorTests.swift`
- Repository-wide test search for subscription tiers, premium features, and entitlement behavior

### Supporting searches

- Repository-wide searches for tier comparisons, `isEntitled`, feature names, product identifiers, authorization/account/owner/role concepts, protected action entry points, and mock subscription behavior

## Current authorization model

### Tier hierarchy

| Tier | Effective rank | Intended access |
|---|---:|---|
| Starter | 0 | Single scans, manual review, evidence, and save flows |
| Plus | 1 | Starter plus automatic screenshot detection and likely-event triage |
| Premium | 2 | Plus plus document import, duplicate clustering, and advanced reminder plans |

`SubscriptionTier.includes(_:)` implements a monotonic hierarchy: Premium includes Plus features, and Plus includes features whose required tier is Plus. This is compact and correct for the current three-tier product.

### Feature matrix observed in code

| Feature | Declared tier | UI gate observed | Operation-boundary gate observed | Assessment |
|---|---|---|---|---|
| Automatic screenshot detection | Plus | Yes | Partial; card visibility is gated, photo observation/loading is not modeled as an entitled operation | Needs hardening |
| Likely-event triage | Plus | Yes | Partial; `IntelligenceUsagePolicy.consume` denies Starter, but accepts a caller-supplied tier | Reasonable local guard, improve source of truth |
| PDF/Files document import | Premium | Yes | No; public scan/import path does not independently check access | High finding |
| Duplicate clusters | Premium | Yes | Partial; view computation and chip are guarded, underlying similarity service is ungated | Acceptable today, centralize before reuse |
| Advanced reminder plans / RSVP deadline reminder | Premium | Yes | No at save side-effect; reminder creation trusts mutable view-model state | High finding |

### Positive controls

- StoreKit transactions are accepted only through `VerificationResult.verified` in `SubscriptionService.checkVerified`.
- `Transaction.currentEntitlements` is used as the live entitlement source; revoked transactions are excluded.
- Initial production tier is Starter, which is fail-closed while StoreKit status is loading.
- `AppState.subscriptionTier` is `private(set)` and mirrors the production subscription service.
- `PremiumFeature` is a closed, enumerable list with a single required-tier mapping.
- `IntelligenceUsagePolicy` returns zero when a tier does not include a feature.
- Existing tests verify core tier inclusion and daily triage budgets.
- Debug screen simulation is wrapped in `#if DEBUG`.

## Findings

### F-01 — Document import is authorized only at the UI trigger

**Severity:** High

**Evidence:** `HomeEmptyStateView` checks `.documentImport` before setting `showFileImporter`, but the file-import completion directly calls `ScanViewModel.scanDocument(at:modelContext:)`. `ScanViewModel` exposes scan entry points without an entitlement dependency or policy check.

**Impact:** A future alternate entry point, deep link, refactor, test harness, accessibility action, or state bug can invoke the premium operation without passing the paywall check. Today this is primarily a subscription revenue-control failure, not remote privilege escalation.

**Immediate remediation:** Put a deny-by-default feature check in the document-import use-case/action boundary. The UI should still preflight for good UX, but `scanDocument` or a dedicated document-import coordinator must reject an unentitled request with a typed access-denied result.

**Exit criteria:** Starter and Plus cannot execute document import through any callable entry point; Premium can; unit tests exercise the operation directly without relying on SwiftUI.

### F-02 — Premium RSVP deadline reminder can be created without an operation-level entitlement check

**Severity:** High

**Evidence:** `EventReviewEditView` passes an entitlement Boolean to the reminder UI, but `EventReviewViewModel.save` creates a deadline reminder whenever `deadlineReminderEnabled` is true and a proposed date exists. The view model has no entitlement/policy dependency and does not re-check immediately before the side effect.

**Impact:** Stale UI state during downgrade/revocation or direct programmatic mutation can create a Premium-only reminder for a lower tier.

**Immediate remediation:** Authorize `.advancedReminderPlans` inside the save/action path immediately before `createDeadlineReminder`. If access is absent, clear/ignore the premium option and return a typed denial that the view can translate to the appropriate paywall or message.

**Exit criteria:** A Starter/Plus save can never create a deadline reminder even when the view-model flag is forced true; a Premium save can; downgrade-during-edit is tested.

### F-03 — Authorization decisions are split across UI state, domain enums, budget policy, and service callers

**Severity:** Medium

**Evidence:** Access is evaluated through `AppState.isEntitled`, direct tier comparisons (`isPlusMember`, `isPremiumMember`), `SubscriptionTier.includes`, and `IntelligenceUsagePolicy`. `HomeViewModel.triageLikelyEvents` receives a tier argument from its caller rather than resolving an entitlement snapshot from an injected authority.

**Impact:** New entry points can omit checks; policy changes require auditing many call sites; callers can accidentally pass stale or incorrect tier state.

**Immediate remediation:** Introduce one small, pure feature-access policy and one entitlement provider protocol. Keep `PremiumFeature` and `SubscriptionTier`, but have both UI preflight and protected actions ask the same policy using a verified entitlement snapshot. Do not introduce social roles now.

**Exit criteria:** No protected operation authorizes itself from a raw caller-supplied tier or ad hoc Boolean; direct tier comparisons remain presentation-only.

### F-04 — Entitlement freshness and status are represented only as a tier

**Severity:** Medium

**Evidence:** `SubscriptionService.currentTier` starts at Starter and updates asynchronously. `AppState` mirrors it. The model cannot distinguish verified Starter from loading, StoreKit unavailable, verification failure, or a recently revoked subscription. Foreground handling refreshes permission state but does not explicitly refresh StoreKit status.

**Impact:** Fail-closed behavior is safe for access, but UX and diagnostics cannot explain temporary downgrades. Future network/server entitlements would need freshness and provenance to prevent stale authorization.

**Immediate remediation:** Represent entitlement state as a snapshot containing at least tier, resolution state, evaluated timestamp, and provenance. Refresh on launch, transaction updates, purchase/restore, and scene activation. Continue denying paid operations unless the snapshot is verified.

**Exit criteria:** Tests cover loading, verified Starter/Plus/Premium, revoked/expired, verification failure, and foreground refresh; UI can distinguish “checking access” from “Starter.”

### F-05 — Product-to-tier mapping is duplicated

**Severity:** Medium

**Evidence:** Product IDs and tier inference appear in `SubscriptionService`, `PurchaseViewModel.Plan`, `ManagePlanView`, `DateSnap.storekit`, and release documentation.

**Impact:** Adding or renaming a product can cause purchasing, display, and entitlement resolution to disagree. A string-contains inference such as `productID.contains("premium")` is not an authorization-grade mapping.

**Immediate remediation:** Centralize known product definitions and exact product-ID-to-tier mapping in one typed catalog used by subscription resolution and purchase presentation. Unknown product IDs must not grant access.

**Exit criteria:** One exact mapping source, exhaustive tests for four current IDs, and deny-by-default test for unknown IDs.

### F-06 — Transaction verification failures are silently discarded

**Severity:** Medium

**Evidence:** The transaction listener catches verification errors without recording a safe diagnostic; current-entitlement enumeration also continues silently.

**Impact:** Access correctly fails closed, but release QA and support cannot distinguish fraud/verification failures from StoreKit availability or product configuration problems.

**Immediate remediation:** Add privacy-safe structured logging and observable resolution status. Never log signed payloads, account identifiers, or purchase tokens.

**Exit criteria:** Verification failures remain denied and produce a testable, non-sensitive diagnostic/status.

### F-07 — Tests validate policy tables, not protected actions

**Severity:** High

**Evidence:** `AdvisorTests` checks tier inclusion and local budgets. No reviewed test proves that Starter/Plus are denied at document-import or deadline-reminder execution boundaries, or that a downgrade/revocation removes access without relaunch.

**Impact:** UI refactors can create entitlement bypasses while policy-table tests remain green.

**Immediate remediation:** Add parameterized tests for every feature/tier pair and integration-style unit tests that call each protected action directly. Include transition tests for purchase, restore, expiration, revocation, and downgrade while a gated flow is open.

**Exit criteria:** Every `PremiumFeature` has allow/deny action-boundary coverage across all tiers; bypass regression tests fail before the remediation and pass afterward.

### F-08 — Mock subscription defaults to Plus and the environment has a permissive fallback container

**Severity:** Medium

**Evidence:** `MockSubscriptionService.currentTier` always returns Plus, and `EnvironmentValues.services` defaults to `ServiceContainer.mock()`.

**Impact:** Tests/previews that accidentally omit dependency injection may mask missing entitlement wiring. Production app construction explicitly injects `.live()`, so this is not currently a direct production bypass.

**Immediate remediation:** Make mock tier injectable and default it to Starter. Prefer an assertion/failing dependency for protected-action tests where omission should be detected; retain explicit Plus/Premium preview fixtures.

**Exit criteria:** Tests state their tier explicitly, missing injection does not silently grant paid access, and previews can still select each tier intentionally.

### F-09 — Current code has no identity, ownership, or social-resource authorization

**Severity:** Informational / future boundary

**Evidence:** No account, authenticated principal, owner ID, participant membership, server API, or shared-resource ACL was found. Existing “authorization” references are Apple framework permissions or subscriptions.

**Impact:** None for the current local-only product. Reusing subscription tiers as future social roles would create serious confused-deputy and cross-user access risks.

**Immediate remediation:** None beyond naming and modular boundaries. Do not add speculative `admin`, `host`, `member`, or `guest` cases to `SubscriptionTier`.

**Exit criteria:** Current code keeps commercial entitlements separate from any future identity/resource authorization model.

## Immediate remediation plan

### Phase 1 — Establish a single local authorization contract

1. Add a small `FeatureAccessPolicy` (name may vary) near `FeatureEntitlements.swift` that evaluates a `PremiumFeature` against an entitlement snapshot and returns a typed decision.
2. Add an `EntitlementProviding` protocol to the subscription layer. It should expose current snapshot and an async refresh mechanism; avoid making view code the authority.
3. Model decisions as allow/deny with a stable reason such as `requiresTier`, `checkingEntitlements`, `unverified`, or `unavailable`. Do not use paywall presentation as the policy result.
4. Keep the current tier hierarchy and five features. Do not add future social roles or permissions.

**Files likely involved:** `FeatureEntitlements.swift`, `SubscriptionService.swift`, `ServiceContainer.swift`, `AppState.swift`, tests.

### Phase 2 — Enforce at current action boundaries

1. Guard document import inside its use case or `ScanViewModel` entry point.
2. Guard deadline-reminder creation inside `EventReviewViewModel.save` immediately before the side effect.
3. Route likely-event triage through the entitlement provider rather than trusting a raw tier parameter; keep daily budget enforcement.
4. Encapsulate duplicate-cluster generation behind a gated operation before it is reused outside `HistoryArchiveView`.
5. Treat automatic screenshot detection as a gated use case, not only a conditional card.
6. Preserve UI preflight/paywalls as presentation behavior, backed by the same policy.

**Files likely involved:** `ScanViewModel.swift`, `HomeViewModel.swift`, `HomeEmptyStateView.swift`, `EventReviewViewModel.swift`, `EventReviewEditView.swift`, `HistoryArchiveView.swift`, feature policy and tests.

### Phase 3 — Normalize StoreKit entitlement state

1. Create a typed, exact product catalog for the four known IDs.
2. Replace duplicated/string-derived tier mapping.
3. Publish entitlement resolution state and privacy-safe diagnostics.
4. Refresh on launch, transactions, purchase/restore, and foreground activation.
5. Keep unknown/unverified/revoked/expired products fail-closed.

**Files likely involved:** `SubscriptionService.swift`, `PurchaseViewModel.swift`, `ManagePlanView.swift`, `ContentView.swift`, `DateSnap.storekit`, tests.

### Phase 4 — Add authorization regression tests

1. Add an exhaustive matrix test over every tier and `PremiumFeature`.
2. Directly test protected operations; do not test only button visibility.
3. Add transition tests: loading to verified, Starter to paid, Premium to Starter, revocation/expiration, unknown product, verification failure, and foreground refresh.
4. Make mocks injectable and deny by default.
5. Add UI tests only for paywall routing and visible state; keep authorization assertions in unit/integration tests.

**Files likely involved:** `Tests/DateSnapTests/AdvisorTests.swift`, new focused entitlement/action tests, mock services.

## Recommended immediate design constraints

- **Deny by default:** Unknown feature, product, or unresolved entitlement grants nothing.
- **One authority:** StoreKit-derived verified entitlement snapshot is the current authority.
- **Two-layer enforcement:** UI preflight for experience; action-boundary check for correctness.
- **Typed capabilities:** Continue using stable feature identifiers rather than scattered plan-name comparisons.
- **Commercial tier is not identity role:** Starter/Plus/Premium must never become host/moderator/member authorization.
- **No persisted trust in UI state:** A Boolean toggle or cached tier is not sufficient to authorize a side effect.
- **No client-authoritative social writes later:** Any future shared-resource mutation must be authorized server-side.
- **Safe observability:** Log decision categories and feature identifiers, never StoreKit payloads or future message/event private content.

## Future extensibility guardrails (not immediate implementation work)

When DateSnap gains shared events or social features, add a separate authentication and resource-authorization subsystem rather than expanding `SubscriptionTier`.

The future model should separate four dimensions:

| Dimension | Example future values | Authority |
|---|---|---|
| Identity | authenticated user/service principal | Authentication provider/server |
| Commercial entitlement | Starter, Plus, Premium, add-on | StoreKit plus server reconciliation if server features exist |
| Resource relationship | event owner, host, co-host, invited participant, blocked user | Server-side event membership data |
| Action/capability | edit event, invite, RSVP, comment, moderate, message, integrate | Server-side policy evaluated per resource |

Future policy should evaluate **principal + action + resource + relationship + commercial capability + context**, with server-side deny-by-default enforcement. Event ownership, invitations, message membership, blocks, moderation, and integration tokens must never be trusted solely from iOS UI claims. Third-party tokens should be held server-side where possible, scoped minimally, revocable, and never logged.

These are compatibility guardrails only. No future tables, roles, endpoints, token storage, or social services should be added during the immediate entitlement remediation.

## Verification matrix

| Area | Verification | Pass criteria | Priority |
|---|---|---|---|
| Tier hierarchy | Exhaustive tier/feature unit test | Exact current matrix; Premium inherits Plus | Blocker |
| Document import | Invoke operation directly for each tier | Only Premium executes | Blocker |
| Deadline reminder | Force enabled state and save for each tier | Only Premium creates side effect | Blocker |
| Automatic detection | Invoke gated use case directly | Starter denied; Plus/Premium allowed | High |
| Likely-event triage | Invoke without caller-controlled tier | Authority snapshot controls access and budget | High |
| Duplicate clusters | Invoke gated operation directly | Only Premium receives result | High |
| Initial resolution | Cold launch with delayed StoreKit | Paid action denied while checking; distinct loading UX | High |
| Purchase/restore | Simulated verified transactions | Snapshot updates immediately and consistently | High |
| Expiration/revocation | Transition while gated screen is open | Next action is denied; UI updates without relaunch | Blocker |
| Unknown product | Inject verified unknown product | No paid access granted | Blocker |
| Verification failure | Inject unverified result | Denied with safe diagnostic | Blocker |
| Missing dependency | Construct protected action without explicit authority | Test/build failure or deny-by-default behavior | High |
| Product catalog parity | Compare code, StoreKit config, App Store Connect | Exact four-ID mapping agrees | High |
| Future separation | Architecture review | No social role or ownership logic in subscription tier | Medium |

## Release recommendation

Treat F-01, F-02, and F-07 as required pre-release fixes for trustworthy paid-feature enforcement. F-03 through F-06 and F-08 are required hardening unless the release owner explicitly accepts and records their risk. F-09 is not an immediate implementation task; it is an architectural boundary that should be preserved so a future social system can add server-authoritative identity and resource permissions without rewriting the commercial entitlement model.
