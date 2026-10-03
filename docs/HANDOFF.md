# DateSnap-iOS Recovery Handoff - 2026-10-02

## Where things stand (verified green)
- Branch `recovery/integrate-20261002`, head **1156fc3**, working tree clean (untracked: scripts/, graphify-out/).
- Full suite: **63 tests / 18 suites, all passing** (3.9s, iPhone 18 Pro sim).
- Recovery complete at the branch level: Gen A (rescue 816101d) + Gen B (snapshot 11601b7) + Gen C (agent 3e60e9a) + Gen D (codex sweep, commits 3b32c7f/7d793d5/dc4f7a7/c3b7d3d) are merged and reconciled.

## What was done (chronological, with commits)
1. 12:23-14:40 - Generations recovered/frozen: 816101d, 11601b7, 3e60e9a, e708c6a, merges 54f612a/b634f9c.
2. Gen D capture: 3b32c7f + 7d793d5 (entitlement resolver + policy tests).
3. 15:05 - Live codex session (PID 93534, terminal s021) committed dc4f7a7 ("preserve failure reasons") + c3b7d3d ("align EventKit failure fixtures") then ended. Audited, not reverted.
4. 16:08 - Commit **313d175**: deny reason now names the FEATURE's required tier (`feature.requiredTier`), not the user's own tier; matrix test + persistence fixtures aligned. This fixed the last 3 failures.
5. 17:12 - Commit **1156fc3**: restored 2 Gen A denial tests (Photos denial never prompts; notification denial yields partial save, not silent success). 61 -> 63 tests.

## IMMEDIATE NEXT STEP (one command)
Promotion to main has NOT run yet. Run:
    bash ~/Downloads/round23-finish.sh --promote
It merges to main, smoke-tests main, tags `recovery-integrated-20261002`, and auto-rolls back main if the smoke run fails. (Script also archived at ~/datesnap-recovery-20261002-142441/round23-finish/.)
After that, delete the local round scripts or commit them under scripts/ - your choice.

## Open loops / never fully finished
1. **Cross-check rescue test inventory.** Rescue 816101d had suites whose current-tree status was not exhaustively diffed (AdvisorTests, AppleIntelligenceLiveTests, EventUnderstandingPipelineTests, EvidenceValidationTests, ExtractionEvaluationTests, InterpretationRecordTests, EventUnderstandingTests, DateSnapInferenceTests, PurchaseViewModelTests). The two KNOWN missing tests are ported; verify no OTHER @Test silently vanished by diffing `git show 816101d:Tests/...` test names against current files. The full inventory is in round21's report (~/datesnap-recovery-20261002-142441/round21/report.txt).
2. **User-facing denial phrasing.** Gen A originally expected "Notifications are denied"; current fixtures inject "Injected notification failure". Behavior is covered, but consider restoring a human-readable denial message in EventReviewViewModel before App Store polish.
3. **graphify-out/ untracked directory** - origin unconfirmed (possibly a codex artifact). Inspect before deleting; do not commit blindly.
4. **codex commits dc4f7a7/c3b7d3d were accepted on trust + green tests** - a deeper line-by-line review of the 26-file codex sweep was never done. Low urgency (suite is green) but worth a skim.
5. **Entitlement `@MainActor` on FeatureAccessPolicy** - fine now; revisit if policy gets called from background queues.

## Incident learnings (for future agent runs)
- Concurrent codex sessions commit to the same branch: always `ps aux` sweep + 5-min mtime sweep before edits/builds.
- Capture unknown agent work as named wip generations, never reset.
- Fix direction: richer error messages live in the implementation; align test fixtures to them (codex precedent c3b7d3d).
- Deny reasons must state the required tier, never echo the user's tier.
- Every round: backup to ~/datesnap-recovery-20261002-142441/, commit only on green, xcodebuild needs DEVELOPER_DIR exported.
