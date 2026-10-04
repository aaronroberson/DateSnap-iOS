#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
allowlist="$repo_root/scripts/mock-allowlist.txt"

if [[ ! -f "$allowlist" ]]; then
  echo "Missing allowlist: scripts/mock-allowlist.txt" >&2
  exit 2
fi

rg_args=(
  --hidden
  --no-heading
  --line-number
  --color never
  --glob '!.git/**'
  --glob '!lancedb/**'
  --glob '!Assets.xcassets/**'
  --glob '!build/**'
  --glob '!DerivedData/**'
  --glob '!node_modules/**'
  --glob "!docs/**"
  --glob "!README.md"
  --glob '!scripts/verify-no-mock.sh'
  --glob '!scripts/mock-allowlist.txt'
)

unallowlisted=0
allowlisted=0

is_allowlisted() {
  local category="$1"
  local path="$2"
  local text="$3"
  local row_category row_path row_match owner reason

  while IFS='|' read -r row_category row_path row_match owner reason; do
    [[ -z "$row_category" || "$row_category" == \#* ]] && continue
    [[ "$row_category" == "$category" ]] || continue
    [[ "$path" == $row_path ]] || continue
    [[ "$row_match" == "*" || "$text" == *"$row_match"* ]] || continue
    [[ -n "$owner" && -n "$reason" ]] || continue
    return 0
  done < "$allowlist"

  return 1
}

scan_rule() {
  local category="$1"
  local pattern="$2"
  local hit file line text

  while IFS= read -r hit; do
    IFS=: read -r file line text <<< "$hit"
    file="${file#./}"
    if is_allowlisted "$category" "$file" "$text"; then
      ((allowlisted += 1))
    else
      printf 'UNALLOWLISTED [%s] %s:%s %s\n' "$category" "$file" "$line" "$text" >&2
      ((unallowlisted += 1))
    fi
  done < <(rg "${rg_args[@]}" -P "$pattern" "$repo_root" || true)
}

scan_rule mock-prefix '\bMock[A-Z][A-Za-z0-9_]*\b'
scan_rule sample-title 'NEON SUNSET|ROOFTOP SESSION|SUMMIT_2025\.PDF'
scan_rule stitch-id '(?i)\bstitch[_ -]?[a-z0-9-]{4,}\b'
scan_rule simulation-copy '(?i)simulation hub'
scan_rule hard-coded-price '\$[0-9]+\.[0-9]{2}'
scan_rule mutation-try '\btry\?\s*(?:await\s+)?(?:[[:alnum:]_]+\??\.)+(?:save|delete|remove|create)[[:alnum:]_]*\s*\('
scan_rule todo-marker '\b(TODO|FIXME|HACK|XXX|TBD)\b'

if (( unallowlisted > 0 )); then
  printf 'Found %d unallowlisted mock or stale-state markers (%d allowlisted).\n' "$unallowlisted" "$allowlisted" >&2
  exit 1
fi

printf 'No unallowlisted mock or stale-state markers found (%d allowlisted hits).\n' "$allowlisted"
