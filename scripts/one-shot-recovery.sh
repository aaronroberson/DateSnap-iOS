#!/bin/bash
# one-shot-recovery.sh - DateSnap-iOS lost-work triage, all-in-one.
# 1) Kills any opencode TUI sitting in the repo   2) Backs up + snapshot-commits the tree
# 3) Attributes the diff (Codex plan doc vs unattributed)
# 4) Dumps opencode session records + best-effort Write/Edit extraction
# Usage: bash one-shot-recovery.sh [--test]    (--test also runs swift test at the end)
set -u
REPO="$HOME/apps/DateSnap-iOS"
DB="$HOME/.local/share/opencode/opencode.db"
OUT="$HOME/datesnap-recovery-$(date +%Y%m%d-%H%M%S)"
PLAN="docs/plans/2026-10-02-mock-data-phases-3-5-plan.md"
RUN_TESTS=0; [ "${1:-}" = "--test" ] && RUN_TESTS=1
mkdir -p "$OUT"; REPORT="$OUT/REPORT.md"
exec > >(tee -a "$REPORT") 2>&1
echo "# One-shot recovery run - $(date)"

echo; echo "==== STEP 1: Stop live opencode sessions on this repo ===="
for pid in $(pgrep -x opencode); do
  CWD=$(lsof -a -p "$pid" -d cwd 2>/dev/null | awk 'NR==2{print $NF}')
  case "$CWD" in
    "$REPO"|"${REPO}/"*)
      echo "Killing opencode PID $pid (cwd=$CWD)"
      kill -TERM "$pid" 2>/dev/null; sleep 3
      kill -0 "$pid" 2>/dev/null && { echo "escalating to kill -9 $pid"; kill -9 "$pid"; sleep 1; }
      kill -0 "$pid" 2>/dev/null && echo "WARNING: $pid survived" || echo "PID $pid stopped."
      ;;
    "") ;;
    *) echo "opencode PID $pid in $CWD - left alone" ;;
  esac
done
echo "(PandaOS background 'opencode serve' helpers are left running - they are harmless.)"

echo; echo "==== STEP 2: Backup + snapshot-commit the working tree ===="
cd "$REPO" || { echo "FATAL: cannot enter $REPO"; exit 1; }
tar -czf "$OUT/repo-backup.tgz" --exclude .build --exclude .git --exclude graphify-out --exclude .swiftpm -C "$HOME/apps" "$(basename "$REPO")" \
  && echo "Backup written: $OUT/repo-backup.tgz ($(du -h "$OUT/repo-backup.tgz" | cut -f1))"
git status --short
BRANCH="wip/tree-snapshot-$(date +%Y%m%d-%H%M)"
if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard | grep -v graphify-out | head -1)" ]; then
  git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH" 2>/dev/null
  git add -A -- ':!graphify-out'
  git commit -m "wip: snapshot tree (recovered incident work + phases 3-5, provenance unverified)"
  PREV=$(git rev-parse --abbrev-ref HEAD@{1} 2>/dev/null || echo main)
  git checkout "$PREV" 2>/dev/null
  echo "Snapshot committed on branch: $BRANCH (switched back to $PREV)"
else
  echo "Tree already clean - no snapshot needed."
fi

echo; echo "==== STEP 3: Attribute the diff (plan doc = Codex phases 3-5) ===="
if [ -f "$PLAN" ]; then
  echo "-- plan doc exists; files it mentions: --"
  grep -n -E "ScanViewModel|ReminderScheduleEditor|MutationResult|EventReviewViewModel|SavedEventActions|PaywallView|ManagePlan|NoDatesFound|HistoryArchive|EventReviewEdit|PurchaseViewModel|SwiftDataEntities|ServiceContainer|SubscriptionService|pbxproj|project.yml" "$PLAN" | head -40 | tee "$OUT/plan-doc-mentions.txt"
else
  echo "plan doc not found at $PLAN"
fi
echo "-- diff files and attribution guess: --"
CHANGED=$( (git diff --name-only; git ls-files --others --exclude-standard | grep -v graphify-out) | sort -u )
for f in $CHANGED; do
  base=$(basename "$f" | sed 's/\.swift$//; s/\.pbxproj$//')
  if [ -s "$OUT/plan-doc-mentions.txt" ] && grep -qi "$base" "$OUT/plan-doc-mentions.txt"; then
    echo "CODEX-PLAN : $f"
  else
    echo "UNATTRIBUTED: $f"
  fi
done

echo; echo "==== STEP 4: opencode session records for this repo ===="
SESS=$(sqlite3 -json "$DB" "SELECT id, datetime(time_updated/1000,'unixepoch') AS utc FROM session WHERE directory LIKE '${REPO}%' ORDER BY time_updated DESC LIMIT 4;" 2>/dev/null)
echo "$SESS" | jq -r '.[] | "\(.id)  last-update(UTC): \(.utc)"' 2>/dev/null
IDS=$(echo "$SESS" | jq -r '.[].id' 2>/dev/null)
for sid in $IDS; do
  F="$OUT/parts-$sid.json"
  sqlite3 -json "$DB" "SELECT id, data FROM part WHERE session_id='$sid' ORDER BY id;" > "$F" 2>/dev/null
  SIZE=$(wc -c < "$F"); echo "-- session $sid -> $F ($SIZE bytes)"
  echo "   file paths touched (any tool):"
  jq -r '.data | fromjson? | select(.tool // .type == "tool" or .tool != null) | .state.input.file_path // .input.file_path // empty' "$F" 2>/dev/null | sort -u | head -25
  echo "   write/edit file paths + disk hash match:"
  jq -r '.data | fromjson? | select((.tool // "") | test("write|edit|patch|multiedit";"i")) | [(.state.input.file_path // .input.file_path // ""), (.state.input.content // .input.content // "" | @base64)] | @tsv' "$F" 2>/dev/null \
  | sort -u | while IFS=$'\t' read -r p b64; do
      [ -z "$p" ] && continue
      case "$p" in /*) FP="$p";; *) FP="$REPO/$p";; esac
      if [ ! -f "$FP" ]; then echo "   MISSING: $p"; continue; fi
      if [ -z "$b64" ]; then echo "   NOTED(no content in part): $p"; continue; fi
      if [ "$(printf '%s' "$b64" | base64 -d 2>/dev/null | shasum -a 256 | cut -d' ' -f1)" = "$(shasum -a 256 "$FP" | cut -d' ' -f1)" ]; then
        echo "   MATCH:   $p"
      else
        echo "   DIFFERS: $p (disk != session content)"
      fi
    done
done

echo; echo "==== STEP 5: opencode snapshot stores (fallback recovery source) ===="
find "$HOME/.local/share/opencode" -maxdepth 3 -type d \( -iname "*snapshot*" -o -iname "*storage*" \) 2>/dev/null | head -10

echo; echo "==== STEP 6: Tests ===="
if [ "$RUN_TESTS" = "1" ]; then
  swift test 2>&1 | tail -40
else
  echo "(skipped - rerun with: bash $0 --test)"
fi

echo; echo "==== DONE ===="
echo "Report + dumps: $OUT"
echo "NEXT: paste REPORT.md (or at least steps 3-4) back into the Littlebird chat."
