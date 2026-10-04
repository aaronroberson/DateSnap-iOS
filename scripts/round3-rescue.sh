#!/bin/bash
# round3-rescue.sh - DateSnap recovery round 3
# 1) Pins a rescue branch to the orphaned 12:23 commit
# 2) Diffs it against the current tree (what the 12:46 reset discarded)
# 3) Extracts both lost plan docs from the session dumps
# 4) Inventories the snapshot-store git repos with timestamps
# Prints to terminal AND copies the full report to your clipboard.
set -u
REPO="$HOME/apps/DateSnap-iOS"
OUT=$(ls -d "$HOME"/datesnap-recovery-* 2>/dev/null | tail -1)
LOG="$OUT/round3-report.txt"
exec > >(tee "$LOG") 2>&1
cd "$REPO" || exit 1

echo "== 1. Rescue orphaned commit 816101d =="
if git cat-file -e 816101d^{commit} 2>/dev/null; then
  git branch -f rescue/mock-data-wip-1206 816101d
  echo "rescue branch pinned: rescue/mock-data-wip-1206 -> 816101d"
  git log -1 --format='%h %ci %s' 816101d
  git show --stat --format='' 816101d | tail -30
else
  echo "816101d not found in object db (would mean gc ate it - unlikely this fast)"
fi

echo
echo "== 2. Current tree vs rescued commit (what changed since 12:23) =="
git diff --stat rescue/mock-data-wip-1206 -- . ':(exclude)graphify-out' | tail -30
echo
echo "-- files ONLY in the rescued commit (candidates for lost content): --"
comm -23 \
  <(git ls-tree -r --name-only 816101d | grep -v graphify-out | sort) \
  <(git ls-tree -r --name-only HEAD | sort)

echo
echo "== 3. Extract write-tool file contents from session dumps =="
for f in "$OUT"/parts-*.json; do
  sid=$(basename "$f"); sid=${sid#parts-}; sid=${sid%.json}
  jq -r '.[] | (.data | if type=="string" then fromjson? else . end
        | select(.type=="tool" and .tool=="write")
        | [(.state.input.file_path // ""), (.state.input.content // "" | @base64)] | @tsv)' "$f" \
  | while IFS=$'\t' read -r p b64; do
      [ -z "$p" ] && continue
      name="$OUT/recovered-$(basename "$p")"
      printf '%s' "$b64" | base64 -d > "$name"
      echo "recovered: $(basename "$p") ($(wc -c < "$name") bytes) from $sid"
    done
done
echo "-- to restore them into the repo (run only if the diff above looks right): --"
echo "cp \"$OUT\"/recovered-2026-10-02-*.md \"$REPO/docs/plans/\""

echo
echo "== 4. Snapshot store inventory (each nested dir = a full git tree state) =="
for s in "$HOME"/.local/share/opencode/snapshot/*/; do
  sess=$(basename "$s")
  for g in "$s"*/; do
    [ -d "$g/objects" ] || continue
    ref=$(git --git-dir="$g" rev-parse HEAD 2>/dev/null) || continue
    ts=$(git --git-dir="$g" log -1 --format='%ci' "$ref" 2>/dev/null)
    n=$(git --git-dir="$g" ls-tree -r --name-only "$ref" 2>/dev/null | wc -l | tr -d ' ')
    echo "$ts  $sess  tree=$(basename "$g")  files=$n"
  done
done | sort | head -40

sleep 2
pbcopy < "$LOG" && echo
echo "== full report copied to clipboard - paste it back here =="
echo "== also saved to: $LOG =="
