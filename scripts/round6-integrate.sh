#!/bin/bash
# round6-integrate.sh - DateSnap recovery round 6
# 0) Identify live agents editing the repo  1) Freeze in-flight changes
# 2) Merge recreated work (wip snapshot)    3) Merge rescue commit
# Never touches main. Never leaves the repo dirty. pbcopy at the end.
set -u
REPO="$HOME/apps/DateSnap-iOS"
OUT=$(ls -d "$HOME"/datesnap-recovery-* 2>/dev/null | tail -1)
LOG="$OUT/round6-report.txt"
exec > >(tee "$LOG") 2>&1
cd "$REPO" || exit 1

echo "== 0. WHO is editing this repo right now? =="
PIDS=$( { pgrep -x opencode; pgrep -x codex; pgrep -x claude; pgrep -x kiro; pgrep -x node; } 2>/dev/null | sort -u )
for pid in $PIDS; do
  cwd=$(lsof -a -p "$pid" -d cwd 2>/dev/null | awk 'NR==2{print $NF}')
  case "$cwd" in
    "$REPO"*)
      echo "LIVE IN REPO: PID $pid  cmd: $(ps -p "$pid" -o command= | head -c 140)"
      ;;
  esac
done
echo "(if nothing listed above, the editor may have finished or uses a different binary name)"

echo
echo "== 1. Freeze in-flight changes on the integration branch =="
git checkout -B recovery/integrate-20261002 main
git status --short
if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard | grep -v graphify-out | head -1)" ]; then
  git add -A -- ':!graphify-out'
  git commit -m "wip: freeze in-flight agent changes pre-integration (provenance unknown)"
  echo "In-flight work frozen."
else
  echo "Tree clean - nothing to freeze."
fi

echo
echo "== 2. Merge the post-reset recreation (wip snapshot 11601b7) =="
MERGE_OK=1
if git merge --no-commit wip/tree-snapshot-20261002-1424 2>"$OUT/merge2-stderr.txt"; then
  git commit -m "merge: post-reset recreation (wip snapshot)"
  echo "Merged clean."
else
  MERGE_OK=0
  echo "Conflicts:"
  git diff --name-only --diff-filter=U | tee "$OUT/conflicted-files.txt"
  mkdir -p "$OUT/merge-versions"
  for f in $(git diff --name-only --diff-filter=U); do
    safe=$(echo "$f" | tr '/' '_')
    git show ":2:$f" > "$OUT/merge-versions/${safe}.ours"    2>/dev/null
    git show ":3:$f" > "$OUT/merge-versions/${safe}.theirs"  2>/dev/null
    echo "  $f (both sides saved to merge-versions/)"
  done
  git merge --abort
  echo "Merge aborted - repo CLEAN."
fi

if [ "$MERGE_OK" = "1" ]; then
  echo
  echo "== 3. Merge the rescue commit (12:23 full state) =="
  if git merge --no-commit rescue/mock-data-wip-1206 2>"$OUT/merge3-stderr.txt"; then
    git commit -m "merge: recover 12:23 WIP (mock-data phases 3-5 + RBAC entitlements)"
    echo "CLEAN MERGE - both recovery sources integrated."
    git log --oneline -5
    echo "Next: swift test, then decide about main."
  else
    echo "Conflicts:"
    git diff --name-only --diff-filter=U | tee "$OUT/conflicted-files.txt"
    for f in $(git diff --name-only --diff-filter=U); do
      safe=$(echo "$f" | tr '/' '_')
      git show ":2:$f" > "$OUT/merge-versions/${safe}.ours"    2>/dev/null
      git show ":3:$f" > "$OUT/merge-versions/${safe}.theirs"  2>/dev/null
      added=$(diff "$OUT/merge-versions/${safe}.ours" "$OUT/merge-versions/${safe}.theirs" | grep -c '^>')
      removed=$(diff "$OUT/merge-versions/${safe}.ours" "$OUT/merge-versions/${safe}.theirs" | grep -c '^<')
      echo "  $f  (ours vs theirs: +$added -$removed)"
    done
    git merge --abort
    echo "Merge aborted - repo CLEAN. Versions saved for review."
  fi
fi

echo
echo "== 4. Recovered session-writes vs current branch =="
for w in "$OUT"/recovered-writes/*; do
  [ -f "$w" ] || continue
  name=$(basename "$w" | sed -E 's/^ses_[A-Za-z0-9]+-[0-9]+-//')
  hw=$(git hash-object "$w" 2>/dev/null)
  hh=$(git rev-parse -q --verify "HEAD:$name" 2>/dev/null)
  if [ "$hw" = "$hh" ]; then st="identical to branch"; elif [ -z "$hh" ]; then st="NOT on branch"; else st="differs from branch"; fi
  printf '%-20s %s\n' "$st" "$name"
done

echo
echo "== 5. Snapshot inventory (debugged) =="
find "$HOME/.local/share/opencode/snapshot" -maxdepth 3 -name HEAD 2>/dev/null | while read -r h; do
  g=$(dirname "$h")
  ts=$(git --git-dir="$g" log -1 --format='%ci' HEAD 2>&1 | head -1)
  echo "$ts  $g"
done | sort | head -40

sleep 2
pbcopy < "$LOG" && echo
echo "== full report copied to clipboard - paste it back here =="
echo "== also saved to: $LOG =="
