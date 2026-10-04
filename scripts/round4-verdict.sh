#!/bin/bash
# round4-verdict.sh - DateSnap recovery round 4
# 1) Extract write-tool contents from session dumps (fixed parsing)
# 2) Three-way verdict for every file: rescue commit vs main vs working tree
# Prints to terminal AND copies the full report to your clipboard.
set -u
REPO="$HOME/apps/DateSnap-iOS"
OUT=$(ls -d "$HOME"/datesnap-recovery-* 2>/dev/null | tail -1)
LOG="$OUT/round4-report.txt"
exec > >(tee "$LOG") 2>&1
cd "$REPO" || exit 1

echo "== 1. Extract write-tool contents (fixed) =="
mkdir -p "$OUT/recovered-writes"
for f in "$OUT"/parts-*.json; do
  sid=$(basename "$f" .json); sid=${sid#parts-}
  i=0
  jq -c '.[] | (.data | if type=="string" then fromjson? else . end
        | select(.type=="tool" and .tool=="write")
        | {p: (.state.input.file_path // .state.input.filePath // "?"), c: (.state.input.content // "")})' "$f" \
  | while IFS= read -r rec; do
      i=$((i+1))
      p=$(printf '%s' "$rec" | jq -r '.p')
      name="$OUT/recovered-writes/${sid}-${i}-$(basename "$p")"
      printf '%s' "$rec" | jq -r '.c' > "$name"
      echo "recovered: $p"
      echo "        -> $name ($(wc -c < "$name" | tr -d ' ') bytes)"
    done
done

echo
echo "== 2. Three-way verdict: rescue(816101d) vs HEAD(main) vs working tree =="
FILES=$( { git diff-tree -r --name-only --no-commit-id 816101d; git status --short | grep -v '->' | cut -c4-; } \
         | sort -u | grep -v graphify-out | grep -v '^\.opencode' )
mkdir -p "$OUT/conflicts"
for f in $FILES; do
  [ -f "$f" ] || continue
  hr=$(git rev-parse -q --verify "816101d:$f" 2>/dev/null)
  hh=$(git rev-parse -q --verify "HEAD:$f" 2>/dev/null)
  hw=$(git hash-object "$f" 2>/dev/null)
  if [ -z "$hr" ]; then
    verdict="WORKING-TREE-ONLY (not in rescue commit)"
  elif [ "$hr" = "$hw" ] && [ "$hr" = "$hh" ]; then
    verdict="SAME-EVERYWHERE - already fully recovered"
  elif [ "$hr" = "$hw" ]; then
    verdict="RESCUE==WORKING-TREE - just commit it"
  elif [ "$hh" = "$hw" ]; then
    verdict="RESCUE-ONLY - restore from rescue/mock-data-wip-1206"
  else
    verdict="3-WAY-CONFLICT - needs eyeball"
  fi
  printf '%s\n    %s\n' "$verdict" "$f"
  case "$verdict" in
    CONFLICT*)
      safe=$(echo "$f" | tr '/' '_')
      git show "816101d:$f" > "$OUT/conflicts/${safe}.rescue" 2>/dev/null
      cp "$f" "$OUT/conflicts/${safe}.working"
      added=$(diff "$OUT/conflicts/${safe}.rescue" "$OUT/conflicts/${safe}.working" | grep -c '^>')
      removed=$(diff "$OUT/conflicts/${safe}.rescue" "$OUT/conflicts/${safe}.working" | grep -c '^<')
      echo "    (working vs rescue: +$added -$removed lines; both versions saved in $OUT/conflicts/)"
      ;;
  esac
done

echo
echo "== 3. Snapshot store inventory (from round 3, re-run cheap) =="
for s in "$HOME"/.local/share/opencode/snapshot/*/; do
  sess=$(basename "$s")
  for g in "$s"*/; do
    [ -d "$g/objects" ] || continue
    ref=$(git --git-dir="$g" rev-parse HEAD 2>/dev/null) || continue
    ts=$(git --git-dir="$g" log -1 --format='%ci' "$ref" 2>/dev/null)
    echo "$ts  $sess  tree=$(basename "$g")"
  done
done | sort | head -40

sleep 2
pbcopy < "$LOG" && echo
echo "== full report copied to clipboard - paste it back here =="
echo "== also saved to: $LOG =="
