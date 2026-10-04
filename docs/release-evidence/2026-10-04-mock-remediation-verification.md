# Mock and Non-Production Code Remediation Verification

Date: 2026-10-04  
Branch: `codex-mock-remediation-phases-2-5`

## Outcome

Repository-level remediation for Phases 2–5 is complete. Final-device and signed-archive evidence remains **verification required** and must be collected from the release candidate before distribution.

## Phase evidence

| Phase | Result | Repository evidence | Remaining verification |
|---|---|---|---|
| 2 — Unsupported controls and claims | Complete | `SettingsState` contains navigation state only; `AutomationSettingsView` retains the consumed enhanced-interpretation preference; reminder settings describe per-event behavior; Privacy Center uses factual data-handling copy; settings ledger added | Exercise Settings navigation on a physical release-candidate device |
| 3 — Misrepresentative fallbacks | Complete | Paywall display uses StoreKit product values; mutation paths return `MutationResult`; cleanup failures are tested; fabricated status and storage metrics are absent | StoreKit sandbox QA in every supported storefront; physical Calendar/Reminders/notification denial tests |
| 4 — Legitimate demos and resilience | Complete | Sample flyer uses the production local pipeline; deterministic/model fallback tests remain; gallery, interpretation diagnostics, sample fixtures, and internal Marketing Kit are Debug-gated | Confirm sample-flyer labeling and review-only behavior in TestFlight |
| 5 — Cleanup completeness | Repository checks complete | `verify-no-mock.sh`, owner/reason allowlist, strengthened `verify-release-content.sh`, failure-injection tests, and settings ledger are present | Signed Release archive scan and physical-device evidence |

## Automated checks run

| Check | Result | Notes |
|---|---|---|
| `scripts/verify-no-mock.sh` | Pass | No unallowlisted production marker found |
| `scripts/verify-release-content.sh` | Pass, source portion | Release executable scan intentionally reports skipped when no `.app` is supplied |
| Swift syntax parse for Debug-isolation changes | Pass | `MarketingKitView.swift`, `SettingsClusterView.swift`, and `SettingsHubView.swift` |
| Release simulator build from isolated worktree | Verification required | Xcode reached optimized Swift compilation, but sandboxed `swift-plugin-server` communication failed and produced macro-expansion errors; this is an execution-environment failure, not accepted release evidence |

## Release-candidate gates

The release manager must complete all of the following from a clean candidate commit:

1. Run the full Xcode test plan with zero failures.
2. Produce a signed Release archive using the authorized Apple Developer team.
3. Run `scripts/verify-release-content.sh --require-app <archive-path>/Products/Applications/DateSnap.app` and retain the output.
4. Complete physical-device QA for Photos denial, Calendar/Reminders denial, local-notification denial, offline StoreKit, sample flyer, cache clearing, and full local-data erasure.
5. Confirm every entry in `scripts/mock-allowlist.txt` retains an owner and reason; reject newly added broad allowlist entries.

Failure of any mandatory gate leaves the release **no-go**.
