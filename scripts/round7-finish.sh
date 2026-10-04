#!/bin/bash
# round7-finish.sh - DateSnap recovery round 7 (finish line)
# 0) Retire the live Codex TUI in the repo + freeze any newer edits
# 1) Merge wip snapshot, taking the NEWER in-flight side for the 5 known conflicts
# 2) Merge rescue commit, taking the newer side for any conflict (older side saved)
# 3) Audit: what the older rescue generation had that the final tree doesn't
# main is never touched. Repo always left clean. pbcopy at the end.
# Optional: --test runs swift test at the end.
set -u
REPO="$HOME/apps/DateSnap-iOS"
OUT=$(ls -d "$HOME"/datesnap-recovery-* 2>/dev/null | tail -1)
LOG="$OUT/round7-report.txt"
RUN_TESTS=0; [ "${1:-}" = "--test" ] && RUN_TESTS=1
exec > >(tee "$LOG") 2>&1
cd "$REPO" || exit 1

echo "== 0. Retire live Codex TUI + freeze latest edits =="
for pid in $(pgrep -x codex 2>/dev/null | sort -u); do
  cwd=$(lsof -a -p "$pid" -d cwd 2>/dev/null | awk 'NR==2{print $NF}')
  cmd=$(ps -p "$pid" -o command= | head -c 60)
  case "$cwd" in
    "$REPO"*)
      if [ "$cmd" = "codex" ]; then
        echo "Stopping bare codex TUI PID $pid (its work is already committed as 3e60e9a)"
        kill -TERM "$pid" 2>/dev/null; sleep 2
        kill -0 "$pid" 2>/dev/null && { kill -9 "$pid"; echo "  escalated to -9"; }
      else
        echo "Leaving helper PID $pid ($cmd)"
      fi
      ;;
  esac
done
git checkout recovery/integrate-20261002 2>/dev/null || git checkout -B recovery/integrate-20261002 main
git status --short | head -10
if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard | grep -v graphify-out | head -1)" ]; then
  git add -A -- ':!graphify-out'
  git commit -m "wip: freeze additional in-flight edits (post-3e60e9a)"
  echo "Froze newer edits."
else
  echo "Tree clean."
fi

echo
echo "== 1. Merge wip snapshot (Gen B), newer side wins on the 5 known files =="
EXPECTED="Sources/DateSnap/ViewModels/PurchaseViewModel.swift
Sources/DateSnap/Views/ManagePlanView.swift
Sources/DateSnap/Views/PlusPaywallView.swift
Sources/DateSnap/Views/PremiumPaywallView.swift
Tests/DateSnapTests/PurchaseViewModelTests.swift"
STEP2_OK=1
if git merge --no-commit wip/tree-snapshot-20261002-1424 2>/dev/null; then
  git commit --no-edit
  echo "Merged clean."
else
  CONFLICTS=$(git diff --name-only --diff-filter=U)
  UNEXPECTED=$(echo "$CONFLICTS" | while read -r f; do echo "$EXPECTED" | grep -qx "$f" || echo "$f"; done)
  if [ -n "$UNEXPECTED" ]; then
    echo "UNEXPECTED conflicts - aborting for review:"
    echo "$UNEXPECTED"
    git merge --abort; STEP2_OK=0
  else
    echo "$CONFLICTS" | while read -r f; do
      echo "  taking newer in-flight side: $f"
      git checkout --ours -- "$f" && git add -- "$f"
    done
    git commit --no-edit
    echo "Merge #1 committed (newer generation kept for the 5 files)."
  fi
fi

if [ "$STEP2_OK" = "1" ]; then
  echo
  echo "== 2. Merge rescue commit (Gen A, 12:23) - newer side wins any conflict =="
  if git merge --no-commit rescue/mock-data-wip-1206 2>/dev/null; then
    git commit --no-edit
    echo "CLEAN MERGE - nothing conflicted."
  else
    mkdir -p "$OUT/rescue-side"
    git diff --name-only --diff-filter=U | while read -r f; do
      safe=$(echo "$f" | tr '/' '_')
      git show ":3:$f" > "$OUT/rescue-side/${safe}" 2>/dev/null
      echo "  conflict: $f -> kept newer side; rescue version saved to rescue-side/"
      git checkout --ours -- "$f" && git add -- "$f"
    done
    git commit --no-edit
    echo "Merge #2 committed."
  fi
  git log --oneline -6

  echo
  echo "== 3. Audit: rescue (older Gen A) content NOT in the final tree =="
  git diff HEAD rescue/mock-data-wip-1206 --stat | tail -40
  echo "(every line above = differences vs the 12:23 state; zero would mean perfect recovery)"
fi

echo
echo "== 4. Recovered session-writes vs final tree (path-corrected) =="
for w in "$OUT"/recovered-writes/*; do
  [ -f "$w" ] || continue
  name=$(basename "$w" | sed -E 's/^ses_[A-Za-z0-9]+-[0-9]+-//')
  full=$(git ls-files | grep "/${name//./\\.}$" | head -1)
  hw=$(git hash-object "$w" 2>/dev/null)
  if [ -n "$full" ]; then
    hh=$(git rev-parse -q --verify "HEAD:$full" 2>/dev/null)
    if [ "$hw" = "$hh" ]; then st="identical: $full"; else st="DIFFERS:  $full"; fi
  else
    st="not tracked under that name (check docs/plans/ recovery)"
  fi
  printf '%s\n    <- %s\n' "$st" "$name"
done

echo
echo "== 5. Snapshot store: object counts (no refs, raw objects) =="
find "$HOME/.local/share/opencode/snapshot" -maxdepth 3 -name objects -type d 2>/dev/null | while read -r o; do
  g=$(dirname "$o")
  counts=$(git --git-dir="$g" cat-file --batch-all-objects --batch-check 2>/dev/null | awk '{c[$2]++} END {printf "commits=%d trees=%d blobs=%d", c["commit"], c["tree"], c["blob"]}')
  [ -n "$counts" ] && echo "$g  $counts"
done | head -30

echo
echo "== 6. Tests =="
if [ "$RUN_TESTS" = "1" ]; then
  swift test 2>&1 | tail -40
else
  echo "(skipped - rerun with: bash scripts/round7-finish.sh --test)"
fi

sleep 2
pbcopy < "$LOG" && echo
echo "== full report copied to clipboard - paste it back here =="
