#!/bin/bash
# round5-integrate.sh - DateSnap recovery round 5 (final integration)
# Works on a NEW branch (recovery/integrate-20261002). main is never touched.
# - ff-merges the post-reset recreation (wip snapshot)
# - merges the rescue commit (12:23 full state); if conflicts, saves both
#   sides per file and aborts to a clean state - never leaves a dirty repo
# Prints to terminal AND copies the full report to your clipboard.
set -u
REPO="$HOME/apps/DateSnap-iOS"
OUT=$(ls -d "$HOME"/datesnap-recovery-* 2>/dev/null | tail -1)
LOG="$OUT/round5-report.txt"
exec > >(tee "$LOG") 2>&1
cd "$REPO" || exit 1

echo "== 0. Preconditions =="
git status --short | head -10
git log --oneline -3 main
echo "wip parent:    $(git log --format='parent=%p' -1 wip/tree-snapshot-20261002-1424)"
echo "rescue parent: $(git log --format='parent=%p' -1 rescue/mock-data-wip-1206)"
echo "-- what main already got after the reset: --"
git show --stat --format='%h %s' 30451ec | head -12
git show --stat --format='%h %s' 54002dc | head -12

echo
echo "== 1. Integration branch =="
git checkout -b recovery/integrate-20261002 main

echo
echo "== 2. Fast-forward the post-reset recreation (wip snapshot) =="
if git merge --ff-only wip/tree-snapshot-20261002-1424; then
  echo "FF-merge OK: recreated work is now in the integration branch"
else
  echo "WARNING: not a fast-forward - stopping here for review"
  exit 1
fi

echo
echo "== 3. Merge the rescue commit (12:23 full state) =="
mkdir -p "$OUT/merge-versions"
if git merge --no-commit rescue/mock-data-wip-1206 2>"$OUT/merge-stderr.txt"; then
  echo "CLEAN MERGE - no conflicts. Committing on the integration branch:"
  git commit -m "merge: recover 12:23 WIP (mock-data phases 3-5 + RBAC entitlements)"
  git log --oneline -3
  echo "Next: run swift test, then decide about fast-forwarding main."
else
  echo "Conflicts (expected on the overlapping files):"
  git diff --name-only --diff-filter=U | tee "$OUT/conflicted-files.txt"
  echo
  for f in $(git diff --name-only --diff-filter=U); do
    safe=$(echo "$f" | tr '/' '_')
    git show ":2:$f" > "$OUT/merge-versions/${safe}.ours"    2>/dev/null
    git show ":3:$f" > "$OUT/merge-versions/${safe}.theirs" 2>/dev/null
    added=$(diff "$OUT/merge-versions/${safe}.ours" "$OUT/merge-versions/${safe}.theirs" | grep -c '^>')
    removed=$(diff "$OUT/merge-versions/${safe}.ours" "$OUT/merge-versions/${safe}.theirs" | grep -c '^<')
    echo "  $f  (ours=main-side, theirs=rescue: +$added -$removed differing lines)"
  done
  git merge --abort
  echo
  echo "Merge aborted - repo is CLEAN. Both versions of every conflicted file"
  echo "are saved in $OUT/merge-versions/ for review."
fi

echo
echo "== 4. Recovered-writes vs main (which session writes are already in?) =="
for w in "$OUT"/recovered-writes/*; do
  [ -f "$w" ] || continue
  name=$(basename "$w" | sed -E 's/^ses_[A-Za-z0-9]+-[0-9]+-//')
  hw=$(git hash-object "$w" 2>/dev/null)
  hh=$(git rev-parse -q --verify "HEAD:$name" 2>/dev/null)
  if [ "$hw" = "$hh" ]; then st="identical to main"; elif [ -z "$hh" ]; then st="NOT on main"; else st="differs from main"; fi
  printf '%-28s %s\n' "$st" "$name"
done

echo
echo "== 5. Snapshot inventory (debugged) =="
find "$HOME/.local/share/opencode/snapshot" -maxdepth 3 -name HEAD 2>/dev/null | while read -r h; do
  g=$(dirname "$h")
  ref=$(git --git-dir="$g" rev-parse HEAD 2>&1 | head -1)
  ts=$(git --git-dir="$g" log -1 --format='%ci' HEAD 2>&1 | head -1)
  echo "$ts  $g"
done | sort | head -40

sleep 2
pbcopy < "$LOG" && echo
echo "== full report copied to clipboard - paste it back here =="
echo "== also saved to: $LOG =="
