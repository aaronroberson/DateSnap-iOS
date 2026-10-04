# Git Recovery Inventory — DateSnap-iOS

**Date:** 2026-10-02 (completed 2026-10-03)
**Scope:** Full inventory and disposition of every branch, dangling commit, untracked artifact, and worktree/stash state discovered during recovery of `/Users/conscious/apps/DateSnap-iOS` (remote `github.com/aaronroberson/DateSnap`).
**Companion documents:** [implementation plan](../plans/2026-10-02-handoff-completion-plan.md) · [completion report](2026-10-02-git-recovery-and-handoff-completion-report.md)

## Method

- `git branch -a`, `git log --all --oneline`, `git fsck --full --no-reflogs` for dangling objects.
- Merge-base checks to establish ancestry between every local branch and the recovery head.
- Content review of each dangling commit (`git show --stat`, targeted diffs).
- Worktree and stash sweep: `git worktree list`, `git stash list` (both empty).

## Lineage finding (drives every disposition)

All five local branches are **ancestors of recovery head `1156fc3`** — there is nothing to merge or rebase; consolidation into `preview` is a fast-forward by construction. `origin/main` shares **no history** with the iOS tree at all (see item 2).

## Inventory

| # | Item | Location | Base | Changes | Classification | Action taken | Evidence |
|---|------|----------|------|---------|----------------|--------------|----------|
| 1 | Local `main` | branch `main` @ `54002dc` | — | Pre-recovery iOS trunk | Merge into preview | Contained via lineage; `preview` fast-forwarded through it | `git merge-base --is-ancestor main 1156fc3` → yes |
| 2 | `origin/main` (Figma-Make prototype) | `refs/remotes/origin/main`, 3 commits | independent root | React/Vite web prototype (`src/App.tsx`, `vite.config.ts`, `public/assets/…`), 422 files, no Swift; carries 9 dependabot findings | Exclude but preserve | Left untouched on origin; flagged NEVER-MERGE in report | `git log origin/main --oneline` (3 commits, unrelated tree) |
| 3 | `feature/rbac-entitlements` | branch @ `f0e4844` | ancestor of `1156fc3` | RBAC/entitlements generation work | Merge into preview | Already contained in `preview` via lineage | `git merge-base --is-ancestor f0e4844 1156fc3` → yes |
| 4 | `fix/mock-data-phases-3-5` | branch @ `f0e4844` (same commit as #3) | ancestor of `1156fc3` | Mock-data cleanup phases 3–5 | Merge into preview | Already contained in `preview` via lineage | same merge-base check |
| 5 | `rescue/mock-data-wip-1206` | branch @ `816101d` | ancestor of `1156fc3` | Rescue tree whose test inventory is the ground truth for HANDOFF item 1 | Merge into preview | Already contained in `preview` via lineage | `git merge-base --is-ancestor 816101d 1156fc3` → yes |
| 6 | `wip/tree-snapshot-20261002-1424` | branch @ `11601b7` | ancestor of `1156fc3` | Mechanical WIP snapshot taken at disruption time | Merge into preview | Already contained in `preview` via lineage | `git merge-base --is-ancestor 11601b7 1156fc3` → yes |
| 7 | Implementation branch (formerly `feat/recovery-completion-20261002`) | `feat/handoff-completion-20261002`, cut from `origin/preview` | `origin/preview` | HANDOFF completion commits (see report) | Retain separately | Renamed to reflect handoff-completion role; tracks `origin/preview`; deliberately **not** merged into `preview` | `git branch --show-current` |
| 8 | Dangling commit `f7c66af` (sceneActivation entitlement refresh) | object store (transient) | post-`fc8fd8d` iteration | Wired `refreshEntitlements(.sceneActivation)` into scene-phase handling | Exclude but preserve | Tagged both twins: `wip/sceneActivation-entitlement-refresh-b` → `f7c66af` (a stash-format WIP commit, "WIP on fix/mock-data-phases-3-5: f0e4844") and `wip/sceneActivation-entitlement-refresh-a` → `93455f44`. The object transiently vanished from `git fsck` output between commands and later resolved again — see report §Anomalies | `git cat-file -t f7c66af` → commit; `git rev-parse wip/sceneActivation-entitlement-refresh-b^{commit}` → f7c66af… |
| 9 | Dangling commit `fc8fd8d` (branding + project.yml) | `git fsck` | — | Branding assets and project.yml iteration | Exclude but preserve | Tagged `superseded/branding-and-project-yml` | `git show --stat fc8fd8d` |
| 10 | Dangling commit `51a273f0` (analyzer early iteration) | `git fsck` | — | Early analyzer iteration superseded by shipped analyzer | Exclude but preserve | Tagged `superseded/analyzer-early-iteration` | `git show --stat 51a273f0` parent chain |
| 11 | Dangling commits `a52139cc` / twin `14efdd1d` (branding icon audit) | `git fsck` | — | Icon-audit working states (near-duplicates) | Exclude but preserve | Tagged `superseded/branding-icon-audit` and `superseded/branding-icon-audit-2` | `git show --stat` both |
| 12 | Dangling commit `1776c6f` (eval corpus) | `git fsck` | — | Evaluation corpus data | Exclude but preserve | Tagged `contained/eval-corpus` | `git show --stat 1776c6f` |
| 13 | `graphify-out/` incl. 21 MB `graph.json` | untracked, repo root | — | Code-graph tool output (derived artifact) | Exclude but preserve | `.gitignore` gained a commented `graphify-out/` rule (`98122fa`, +3 lines); no `.graphifyignore` exists in this repo (that config belongs to the InventionScout engagement, a different repository); `graph.json` never tracked in any history | `git log --all -- graphify-out/graph.json` → empty; `git check-ignore -v graphify-out/graph.json` → `.gitignore:14`; `git show 98122fa --stat` → `.gitignore +3` |
| 14 | Stashes | — | — | none existed | n/a | none to preserve | `git stash list` → empty |
| 15 | Worktrees | — | — | none registered | n/a | none to preserve | `git worktree list` → single entry |
| 16 | Tags | — | — | none existed pre-recovery | n/a | 8 preservation tags created (items 8–12) | `git tag -l` |
| 17 | `EntitlementProviding` / `EntitlementProvenance.sceneActivation` scaffolding | `Sources/DateSnap/Services/Advisors/FeatureEntitlements.swift` (protocol :166, provenance :62) | current tree | Orphaned: zero production conformers or callers; only tests reference the policy. The dropped WIP wired `SubscriptionServiceProtocol.refreshEntitlements(.sceneActivation)`, a method that does not exist on today's protocol (WIP predates the protocol split) | Blocked for human review | Deferred with restoration recipe in report; not deleted (compiles, and `@MainActor` policy makes misuse a compile error) | grep: no production conformers of `EntitlementProviding`; no `refreshEntitlements` on `SubscriptionServiceProtocol` |
| 18 | Dangling draft `231f7e0` (test-port draft) | `git fsck` | — | Near-duplicate of tracked `3f5b9f8`; differs by 2 insertions / 19 deletions in `MockDataCleanupTests.swift` | Exclude but preserve | Tagged `superseded/test-port-draft` | `git diff --stat 3f5b9f8 231f7e0` |

## Preserved-work register (why nothing was purged)

Nothing was deleted. Every excluded item survives as a tag, a branch, an ignore-rule plus on-disk file, or an origin ref:

- **`origin/main` web prototype** — not ours to delete; it is the remote's content and may hold Figma-Make provenance someone wants. Flagged only to prevent accidental merge.
- **SceneActivation entitlement WIP (tags `wip/…`)** — a real product idea (refresh entitlements on scene activation) that predated a protocol refactor. Salvageable as new feature work once `refreshEntitlements` is designed; recipe recorded.
- **Superseded dangling commits (tags `superseded/…`)** — cheap to keep (a tag is 41 bytes), and history from the disruption window may be needed for audit until promotion to `main` is done.
- **`contained/eval-corpus`** — evaluation data may be reusable by the evaluation harness even though the commit shape is not mergeable.
- **Superseded test-port draft (`231f7e0`)** — an earlier variant of the rescue-regression port; kept for diffing if the ported tests are ever questioned.
- **`graphify-out/`** — derived artifact with real tooling value locally; excluded from VCS via ignore rules rather than deleted.
