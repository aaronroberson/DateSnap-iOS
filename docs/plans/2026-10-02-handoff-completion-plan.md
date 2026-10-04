# HANDOFF Completion Plan — DateSnap-iOS

**Date:** 2026-10-02 (executed 2026-10-03)
**Input:** [docs/HANDOFF.md](../HANDOFF.md) open loops 1–5, plus the session directive to lower the minimum supported iOS version to 17.
**Branch:** `feat/handoff-completion-20261002`, cut from `origin/preview` @ `98122fa`.
**Companion documents:** [recovery inventory](../audits/2026-10-02-git-recovery-inventory.md) · [completion report](../audits/2026-10-02-git-recovery-and-handoff-completion-report.md)

## Ground rules

- No force-push, no history rewrite, no merges to `preview` from this branch, no touching `main`.
- Every behavioral change lands with a focused test and a green `xcodebuild test` run before the next commit.
- Conventional Commits; `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` exported for every build.

## Work items

| Priority | Item (HANDOFF ref) | Classification | Source files | Planned change | Tests | Dependencies | Exit criteria |
|---|---|---|---|---|---|---|---|
| P0 | Session directive: min iOS 17 (not a HANDOFF item; added in-session) | Config-only, no behavior change | `project.yml`, `Config/DateSnap-Base.xcconfig`, `Package.swift`, `DateSnap.xcodeproj/project.pbxproj` (regenerated via xcodegen) | Deployment target 18.0 → 17.0 everywhere the floor is declared; verify no `available(iOS 18…)` API usage exists that would silently break | Full suite green on the new floor; pre/post xcresult parity check | None | Suite passes on iOS 17 floor with identical pass/skip counts as the iOS 18 baseline; commit `chore(project): lower minimum deployment target to iOS 17` |
| P1 | 1 — Cross-check rescue test inventory | Investigation + gap closure | `Tests/**` vs `git show 816101d:Tests/…`; ground truth `~/datesnap-recovery-20261002-142441/round21/report.txt` | Diff every `@Test` display name (64 rescue → 66 current, name-level); port any test that vanished without an equivalent | Ported tests must pass; net suite count must not regress | None | Every one of the 64 rescue `@Test` names mapped to current coverage as identical / renamed-equivalent / split-covered / ported; no silent losses |
| P1 | 2 — User-facing denial phrasing | Small UX fix | `Sources/DateSnap/ViewModels/EventReviewViewModel.swift`, `Sources/DateSnap/Services/NotificationService.swift` | Restore human-readable message on notification-access denial, mirroring the existing calendar-denial catch | New test: denied notifications surface a human-readable message naming the fix path | None | Denial copy no longer leaks injected fixture strings; test green |
| P1 | 3 — `graphify-out/` untracked directory | Triage + repo hygiene | `.gitignore`, `graphify-out/`, `.graphifyignore` | Identify origin (graphify tool output incl. 21 MB `graph.json`); ignore the directory, keep the per-project tool config out of the ignore | n/a (config) | None | Directory never committable (`git check-ignore` proves it); artifact preserved on disk; documented |
| P2 | 4 — Codex sweep review (dc4f7a7, c3b7d3d, 3b32c7f, 7d793d5) | Line-by-line skim | `Sources/DateSnap/Services/Advisors/**`, `Tests/DateSnapTests/**`, `DateSnap.xcodeproj` | Read each diff in full; scan sweep-scope files for TODOs, force-unwraps, swallowed errors | Existing suite covers; no new tests unless a defect is found | None | Written verdict per commit; any defect filed as follow-up rather than silently absorbed |
| P2 | 5 — `@MainActor` on FeatureAccessPolicy | Audit only, change if warranted | `Sources/DateSnap/Services/Advisors/FeatureEntitlements.swift` | If production callers exist off-main, enforce actor isolation; otherwise document why no change | Compile-error proof if annotation added | Item 4 findings | Recorded decision with caller evidence |

## Explicitly out of scope (human-owned)

| Item | Why blocked |
|---|---|
| Promotion of `preview` → `main` per HANDOFF's `round23-finish.sh --promote` step | Script no longer exists at `~/Downloads/` or the backup dir; `main` is off-limits to this engagement by mandate |
| Completing `EntitlementProviding` (production conformer + `refreshEntitlements`) | New feature work beyond HANDOFF scope; requires protocol design decisions; restoration recipe recorded in report |
| Making production `NotificationService` hermetically testable | Requires injecting `UNUserNotificationCenter`; API-surface change deferred |
| Merging `feat/handoff-completion-20261002` into `preview` | Forbidden by mandate absent explicit instruction |
