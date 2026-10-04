# HANDOFF: DateSnap-iOS mock-marker closure (finale of rounds 34g-34j)

> Historical record only (closed 2026-10-04). Do not execute these instructions.
> Current remediation status and verification evidence are maintained in
> `docs/HANDOFF.md` and `docs/audits/2026-10-04-mock-remediation-closure.md`.

You are taking over the final closure of ~/apps/DateSnap-iOS (branch main) after a
multi-generational recovery effort. The recovery line (Gens A-D) is verified as
presence-equivalent on main via a cherry-pick train; a weekend PR train sits on top.
The only remaining blocker is scanner scope in scripts/verify-no-mock.sh, which is
being resolved by POLICY (globs for artifacts/prose, allowlist rows WITH owner+reason
for intentional fixtures), never by blanket ignores.

Owner: Aaron. Every allowlist row must carry a reason. Never add an allowlist row
without citing evidence. If verify-no-mock.sh surfaces a violation with no documented
verdict, STOP and report - do not improvise.

## State on main (verified 2026-10-04 01:33 PDT)
- 9c91b6a chore(verify): exclude .stitch design mockups from mock-marker scan
- e949da8 chore(verify): scope mock-marker scan to production source (5 globs: design-assets/**, .opencode/**, HANDOFF.md, DateSnap.xcodeproj/**, scripts/verify-release-content.sh self-match; + 8 allowlist rows for Tests/* fixtures and DEBUG-gated SampleFlyer.swift)
- 066c83f chore(verify): adjudicate remaining markers (PurchaseViewModel.swift hard-coded-price = doc-comment example; scripts/download_screens.py stitch-id = intrinsic tooling)
- main is ~2-3 commits ahead of origin/main (unpushed). git status showed 1 dirty entry - identify it first with `git status --porcelain`; if it is the mock-allowlist.txt edit, commit it.
- NOT yet done: README archive, tags, push, cleanup (an earlier summary wrongly claimed these ran).

## Step 1 - collision gate (mandatory before any write)
pgrep -fl 'hermes chat'  -> must be empty
test -e .git/index.lock  -> must not exist
find Sources Tests scripts -mmin -5 -type f combined with git diff --quiet -> no uncommitted recent writes
Abort and report if any trip.

## Step 2 - final four allowlist rows (verdicts already adjudicated with evidence)
Append to scripts/mock-allowlist.txt:
# 2026-10-04 final adjudication (round34i context+blame evidence, all authored 2026-09-29):
sample-title|*EventModels.swift|*|aaron|DEBUG-gated sample OCR fixture data (rawOcrFragments block)
simulation-copy|*HomeEmptyStateView.swift|*|aaron|inside #if DEBUG block (line 420), Simulation Hub
sample-title|*PremiumPaywallView.swift|*|aaron|paywall example-content illustration (intentional demo doc card)
stitch-id|*ScreenGalleryView.swift|*|aaron|internal design-system gallery screen; FOLLOW-UP: verify not user-reachable in release builds
Commit: "chore(verify): allowlist final four adjudicated markers (DEBUG-gated fixtures, intentional demo copy, internal design gallery)"

## Step 3 - full gauntlet must be green
bash scripts/verify-no-mock.sh          -> expect 0 (was 6 unallowlisted, 25 allowlisted)
bash scripts/verify-recovery.sh         -> expect 0
bash scripts/verify-release-content.sh  -> expect 0
If verify-no-mock.sh still exits nonzero: print violations grouped by file + category, STOP, report. Do not add rows without a verdict.

## Step 4 - archive the generated audit README (idempotent)
If README.md exists at repo root: mv README.md docs/audits/2026-10-04-full-audit.md
then: git add docs/audits/2026-10-04-full-audit.md && git commit -m "docs(audits): archive 2026-10-04 generated full audit report (40,528 lines)"
If already absent, skip.

## Step 5 - tags (idempotent; skip any that already exist)
git tag -a recovery-integrated-20261002 -m "Recovery line (Gens A-D) verified on main via cherry-pick train; weekend PR train on top; full gauntlet green after deliberate scanner scope policy (artifacts glob-excluded; fixtures and DEBUG-gated sample code allowlisted with reasons)." main
For the archive tag: if a local branch `preview` still exists, tag its tip; otherwise find the unrelated-history root: git log --format='%H %s' --max-order ... use `git rev-list --max-parents=0 main` to locate 32207c9's descendants OR simply skip if `git branch --list preview` is empty AND the tag exists is false -> create against the preview tip if resolvable via `git log --all --format='%h %s' | head` inspection. If the preview history is unresolvable, SKIP the archive tag and report; do not guess.
git tag -a archive/preview-recovery-line -m "Unrelated-history recovery line (root 32207c9). Superseded by main. Root commit contains a BURNED API key (prefix AQ.Ab8RN6) - DO NOT PUSH this ref to origin."

## Step 6 - push (CRITICAL RESTRICTION)
git push origin main
git push origin recovery-integrated-20261002
DO NOT push archive/preview-recovery-line. Pushing it would publish the burned key's root commit (32207c9) to origin - the owner explicitly decided the key never left this machine and rotation was skipped on that basis. Keep the archive tag local-only as a tombstone. If anyone asks to push it, escalate to Aaron first.

## Step 7 - cleanup (idempotent)
git worktree remove --force /private/tmp/datesnap-main 2>/dev/null
git worktree remove --force /private/tmp/datesnap-pr1 2>/dev/null
git branch -D preview 2>/dev/null   # only AFTER the archive tag points at its tip (step 5)
git worktree prune

## Step 8 - final state report (tee to a file and paste back to Aaron)
git log --oneline -8; git tag -l 'recovery*' 'archive*'; git worktree list;
git status --porcelain | wc -l; git rev-list --count origin/main..main

## Hard rules
- Never touch or delete ~/.gemini/history or ~/.kiro/history.
- No history rewrites, no force pushes, no rebase of main.
- Work directly on main for these chore commits (repo convention this session).
- Tee all output to a report file (e.g. ~/round34j-report.txt) and pbcopy it at the end; Aaron will paste it back.

## Non-blockers queued after closure (VentureScout, separate repo invention-scout)
1. Dirty tree: 27 uncommitted files incl. deletions in components/dossier/ - assumed part of an incomplete catalyst-ui refactor [A]; stash or commit deliberately.
2. Dossier "Failed to fetch" on workspace 4015 persists despite async params fix 3960e074 [A: backend/route/auth cause unknown].
3. Groq migration: 21 direct-Groq call sites should move to lib/meta/ai.ts.
