#!/bin/bash
# round2-triage.sh - DateSnap recovery round 2
# Branch check, real-schema opencode mining, snapshot probe.
# Prints to terminal AND copies the full report to your clipboard at the end.
set -u
REPO="$HOME/apps/DateSnap-iOS"
OUT=$(ls -d "$HOME"/datesnap-recovery-* 2>/dev/null | tail -1)
LOG="$OUT/round2-report.txt"
exec > >(tee "$LOG") 2>&1

echo "== branches =="
cd "$REPO" || exit 1
git branch -a
git log --oneline -8 fix/mock-data-phases-3-5 2>/dev/null || echo "(branch gone)"
git reflog --date=local -20

echo
echo "== plan docs =="
ls docs/plans/ 2>/dev/null
find . -path ./graphify-out -prune -o -name '*.md' -path '*plan*' -print 2>/dev/null | head

echo
echo "== tool-call counts per session =="
for f in "$OUT"/parts-*.json; do
  echo "-- $(basename "$f")"
  jq -r '.[] | (.data | if type=="string" then fromjson? else . end | select(.type=="tool") | .tool)' "$f" | sort | uniq -c | sort -rn
done

echo
echo "== write/edit targets per session =="
for f in "$OUT"/parts-*.json; do
  echo "-- $(basename "$f")"
  jq -r '.[] | (.data | if type=="string" then fromjson? else . end
        | select(.type=="tool")
        | select(.tool=="write" or .tool=="edit" or .tool=="patch" or .tool=="multiedit")
        | .state.input
        | [(.file_path // .filePath // "?"), ((.content // .new_string // "") | length | tostring) + " chars"]
        | @tsv)' "$f" | sort -u | head -30
done

echo
echo "== git-status lines seen in each session (tree state over time) =="
for f in "$OUT"/parts-*.json; do
  echo "-- $(basename "$f")"
  jq -r '.[] | (.data | if type=="string" then fromjson? else . end
        | select(.type=="tool") | .state.output // empty)' "$f" \
    | grep -E 'modified:|new file:|deleted:|On branch' | sort | uniq -c | sort -rn | head -25
done

echo
echo "== snapshot store probe =="
D=$(ls "$HOME/.local/share/opencode/snapshot" | head -1)
echo "sample dir: $D"
find "$HOME/.local/share/opencode/snapshot/$D" -maxdepth 2 2>/dev/null | head -15
if git --git-dir="$HOME/.local/share/opencode/snapshot" rev-parse --is-bare-repository 2>/dev/null; then
  echo "(top-level snapshot dir IS a bare git store)"
fi

sleep 2
pbcopy < "$LOG" && echo
echo "== full report copied to clipboard - just paste it back here =="
echo "== also saved to: $LOG =="
