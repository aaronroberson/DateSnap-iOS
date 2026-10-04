# RBAC and Subscription Entitlements Implementation Plan

Updated: 2026-10-04  
Audit: `docs/audits/2026-10-02-rbac-and-subscription-entitlements-audit.md`

## Path chosen

Use a written plan because the remaining work crosses authorization policy, StoreKit state propagation, several protected operation boundaries, presentation state, and tests. Existing resolver/lifecycle work on `main` will be retained and reviewed rather than rewritten.

## Numbered checklist

1. **F-01 — Document import (High):** authorize inside `ScanViewModel.scanDocument`; return a typed denial; deny Starter, Plus, checking, unverified, and unavailable states; test direct calls and verified Premium.
2. **F-02 — Deadline reminders (High):** re-authorize immediately before reminder creation; deny forced-on Starter/Plus and downgrade-during-edit; test Premium and denied-permission paths.
3. **F-03 — One authoritative policy (Medium):** use `FeatureAccessPolicy` with current `EntitlementSnapshot`; remove caller-supplied tiers and raw entitlement booleans from protected operations; use the same policy for UI preflight.
4. **F-04 — Explicit entitlement state (Medium):** propagate snapshot—not only tier—through `AppState`; distinguish checking from verified Starter; retain launch, transaction, purchase, restore, and scene-activation refresh; deny unless verified.
5. **F-05 — Exact product catalog (Medium):** make the typed catalog the sole four-ID mapping; remove duplicated ID sets and substring inference; deny unknown IDs; retain exhaustive tests.
6. **F-06 — Verification diagnostics (Medium):** log generic privacy-safe failures and expose state through the snapshot; do not log product IDs, transaction data, or localized StoreKit errors.
7. **F-07 — Action and transition tests (High):** cover the complete feature/tier matrix, direct protected actions, checking, expiration, revocation, verification failure, purchase/restore provenance, foreground refresh, downgrade, and denied permissions.
8. **F-08 — Deny-by-default doubles (Medium):** retain removal of production mocks; ensure new test providers default to verified Starter or require explicit snapshots; missing production dependency remains fail-fast.
9. **F-09 — Scope boundary (Informational):** keep subscription entitlements separate from identity/social roles; do not invent roles or tiers.
10. **Release acceptance:** Debug and Release build cleanly with strict concurrency, all tests pass, privacy/configuration files remain accurate, no bypass flags or secrets remain, completion report maps findings to commits, and the feature branch finishes clean.

## Findings mapped to files

| Finding | Files | Work |
| --- | --- | --- |
| F-01, F-03, F-07 | `ScanViewModel.swift`, `HomeEmptyStateView.swift`, action tests | Inject provider, enforce document-import authorization at entry, translate typed denial. |
| F-02, F-03, F-07 | `EventReviewViewModel.swift`, `EventReviewEditView.swift`, action tests | Re-check immediately before deadline-reminder side effect. |
| F-03, F-07 | `HomeViewModel.swift`, `HistoryArchiveView.swift`, advisor/service code | Remove caller tier; gate automatic detection, triage, and duplicate clusters at callable boundaries. |
| F-04 | `AppState.swift`, `ContentView.swift`, subscription tests | Mirror and present the full snapshot; verify every refresh provenance. |
| F-05 | `FeatureEntitlements.swift`, `SubscriptionService.swift`, `PurchaseViewModel.swift`, `ManagePlanView.swift` | Use only exact catalog mappings. |
| F-06 | `SubscriptionService.swift`, tests | Generic diagnostics and observable fail-closed state. |
| F-08, F-09 | `ServiceContainer.swift`, test support, report | Verify deny-by-default DI and preserve domain separation. |

## Order and commits

1. `fix(entitlements): enforce protected scan operations`
2. `fix(entitlements): guard premium deadline reminders`
3. `fix(entitlements): centralize gated advisor operations`
4. `fix(subscriptions): propagate verified entitlement state`
5. `fix(storekit): normalize catalog and safe diagnostics`
6. `test(entitlements): cover transitions and denied permissions`
7. `docs(entitlements): report audit remediation`

Every commit will stage explicit audit-related paths only. `docs/prompts/datesnap-round34j-handoff.md` is unrelated and will remain untouched.

## Test strategy

- Swift Testing matrix tests for all feature/tier and unresolved-state combinations.
- Direct view-model/service invocation tests that bypass UI preflight.
- Recording doubles for file scanning, reminders, calendar, notification, and entitlement changes.
- Resolver tests for active, expired, revoked, unknown, and unverified transactions.
- Purchase/restore and lifecycle-provenance tests using controllable providers and the exact `DateSnap.storekit` identifiers.
- Targeted tests after each behavior change, then all tests plus Debug and Release builds.

## Risks

| Risk | Mitigation |
| --- | --- |
| Stale paid access survives downgrade | Query the provider again at the protected side-effect boundary. |
| UI and operation checks diverge | Both use `FeatureAccessPolicy`; operation checks remain mandatory. |
| Unresolved StoreKit state looks like free tier | Propagate `EntitlementSnapshot.state` and present checking separately. |
| Unknown product unlocks access | Exact catalog lookup only; unknown IDs resolve to no entitlement. |
| Diagnostics disclose transaction details | Log generic state/count only. |
| Existing recovery changes regress | Preserve current resolver/lifecycle code and run targeted plus full validation. |

## Definition of done

- Every finding is resolved or explicitly deferred with evidence and rationale.
- Each protected operation authorizes through the current verified snapshot at execution time.
- StoreKit verification, expiration, revocation, purchase, restore, updates, launch, and foreground refresh are tested.
- Debug and Release builds have no new warnings; all non-opt-in tests pass.
- Privacy manifest, entitlements, Info.plist, catalog, and documentation agree with behavior.
- No debug unlocks, permissive production mocks, secrets, substring tier inference, or caller-supplied authorization tiers remain.
- The completion report contains finding status, commit hashes, files, results, deviations, risks, and follow-ups.
- All audit commits are on `feature/rbac-entitlements-remediation`; unrelated files are excluded and the audit worktree is clean.
