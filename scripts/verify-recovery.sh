#!/bin/bash
# verify-recovery.sh - Cross-checks what agent harnesses CLAIM they wrote
# against what is ACTUALLY on disk and in git. READ-ONLY.
# Usage: bash verify-recovery.sh [repo-path] [hours-back]   (default: ~/apps/DateSnap-iOS, 24h)
set -u
REPO="${1:-$HOME/apps/DateSnap-iOS}"
HOURS="${2:-24}"
OUT="$HOME/recovery-verify-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"; cd "$REPO" || exit 1
echo "# Recovery verification - $(date) - repo: $REPO - window: ${HOURS}h"

echo; echo "=== A. Git: all commits in window, all branches ==="
git log --all --since="${HOURS} hours ago" --format='%h | %ad | %d | %an | %s' --date=iso-local
echo "-- merge in progress? --"; [ -f .git/MERGE_HEAD ] && echo "YES: $(cat .git/MERGE_HEAD)" || echo "no"
echo "-- uncommitted tree --"; git status --short | head -60

echo; echo "=== B. Claude Code transcript cross-check ==="
# Extract Write/Edit file paths + content hashes from jsonl transcripts, compare to disk.
CCP="$HOME/.claude/projects/-$(echo "$REPO" | sed 's|/|-|g')"
CLAIMS="$OUT/claude-claims.txt"; : > "$CLAIMS"
if [ -d "$CCP" ]; then
  find "$CCP" -name '*.jsonl' -mtime -1 2>/dev/null | while read -r f; do
    jq -r 'select(.type=="assistant") | .message.content[]?
      | select(.type=="tool_use" and (.name=="Write" or .name=="Edit" or .name=="MultiEdit"))
      | .input.file_path' "$f" 2>/dev/null
  done | sort | uniq -c | sort -rn | head -40 | tee "$CLAIMS"
  echo "(claims saved to $CLAIMS)"
  echo "-- content hash check for Write payloads: --"
  find "$CCP" -name '*.jsonl' -mtime -1 2>/dev/null | while read -r f; do
    jq -r 'select(.type=="assistant") | .message.content[]?
      | select(.type=="tool_use" and .name=="Write" and .input.file_path and .input.content)
      | "\(.input.file_path)\t\(.input.content | @base64)"' "$f" 2>/dev/null
  done | sort -u | while IFS=$'\t' read -r p b64; do
    [ -f "$p" ] || { echo "MISSING: $p (claimed written, not on disk)"; continue; }
    if [ "$(printf '%s' "$b64" | base64 -d 2>/dev/null | shasum -a 256 | cut -d' ' -f1)" = "$(shasum -a 256 "$p" | cut -d' ' -f1)" ]; then
      echo "MATCH:   $p"
    else
      echo "DIFFERS: $p (disk content != last Write payload - edited after, or recovery changed it)"
    fi
  done | sort | uniq -c | sort -k2 | head -60
else
  echo "no Claude Code project dir found for this repo"
fi

echo; echo "=== C. opencode storage check ==="
OC="$HOME/.local/share/opencode"
if [ -f "$OC/opencode.db" ] && command -v sqlite3 >/dev/null 2>&1; then
  echo "-- tables: --"; sqlite3 "$OC/opencode.db" ".tables" 2>/dev/null | head -5
  echo "-- sessions for this repo (adjust table names per .tables output): --"
  sqlite3 "$OC/opencode.db" \
    "SELECT id, directory, datetime(time_updated/1000,'unixepoch') FROM session WHERE directory LIKE '$REPO%' ORDER BY time_updated DESC LIMIT 8;" 2>/dev/null \
    || echo "(query failed - inspect tables manually)"
else
  echo "opencode.db or sqlite3 not found; check legacy $OC/storage/session"
  [ -d "$OC/storage/session" ] && find "$OC/storage/session" -mtime -1 | head -10
fi

echo; echo "=== D. Codex sessions for this repo ==="
find "$HOME/.codex/sessions" -type f -mtime -1 2>/dev/null | while read -r f; do
  grep -l "$REPO" "$f" >/dev/null 2>&1 && { echo "SESSION: $f"; grep -o '"file_path[^,}]*' "$f" 2>/dev/null | sort -u | head -10; }
done | head -40
[ -d "$HOME/.codex/sessions" ] || echo "no ~/.codex/sessions"

echo; echo "=== E. Kiro session records ==="
find "$HOME/.kiro" -type f -mtime -1 2>/dev/null | head -15
[ -e "$HOME/.kiro" ] || echo "no ~/.kiro"

echo; echo "=== F. Files modified on disk in window (top 30 by recency) ==="
find "$REPO" -type f -mmin -$((HOURS*60)) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' \
  -not -path '*/graphify-out/*' 2>/dev/null -print0 | xargs -0 ls -lt 2>/dev/null | head -30

echo; echo "=== G. Concurrent-agent collision check ==="
echo "Files BOTH claimed by a harness transcript AND modified on disk are expected."
echo "DANGER: two harnesses claiming the SAME file (compare sections B and D lists)."
echo "Run: comm -12 <(sort -u $OUT/claude-claims.txt) <(sort -u $OUT/codex-claims.txt) 2>/dev/null"
echo; echo "=== Done. Nothing modified. Full log: rerun with '| tee $OUT/verify.log' ==="
