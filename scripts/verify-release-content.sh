#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
source_root="$repo_root/Sources/DateSnap"

source_forbidden='ServiceContainer[.]mock[(]|\bMock[A-Za-z0-9_]*Service\b|mock-(calendar-event|reminder|notification|deadline)-'
release_forbidden='InterpretationDiagnosticsView|ServiceContainer[.]mock|Mock[A-Za-z0-9_]*Service|Mock Rooftop Sunset Party|mock-(calendar-event|reminder|notification|deadline)-|All 17 Stitch Screens|Stitch ID:|Screen State & Simulation Hub|6c145dff8ec540b9a51f806629e55c70|sampleNeonSunset|Neon Sunset Rooftop Session|sampleDentalCheckup|Dr. Aris Dental Checkup|sampleSummerMixer|Summer Rooftop Mixer'

# Usage: verify-release-content.sh [--require-app] [/path/to/Built.app]
#   --require-app  (or DATESNAP_REQUIRE_APP=1) makes the Release executable scan
#                  MANDATORY. Use this in the release/archive path: without it a
#                  source-only run exits 0, which is not a release gate.
require_app="${DATESNAP_REQUIRE_APP:-0}"
app_path=""
for arg in "$@"; do
  case "$arg" in
    --require-app) require_app=1 ;;
    -*) echo "error: unknown option: $arg" >&2; exit 2 ;;
    *)  app_path="$arg" ;;
  esac
done

failure=0

# rg exits 0 when it matches, 1 when it does not, and >=2 on error. Treating an
# error as "no matches" silently turns this gate green on a broken scan, so an
# error is fatal here. (Same class of bug as the `|| true` removed from
# verify-no-mock.sh on 2026-10-04.)
rg_scan() {
  local out status
  out="$(mktemp)"
  set +e
  rg "$@" >"$out" 2>"$out.err"
  status=$?
  set -e
  if (( status >= 2 )); then
    echo "FATAL: ripgrep failed (exit $status) during a release gate scan:" >&2
    sed 's/^/  rg: /' "$out.err" >&2
    rm -f "$out" "$out.err"
    exit 3
  fi
  cat "$out"
  rm -f "$out" "$out.err"
  return "$status"
}

echo "Checking production sources for forbidden mock service code..."
if rg_scan --line-number --glob '*.swift' --regexp "$source_forbidden" "$source_root"; then
    echo "error: production mock service code was found under Sources/DateSnap" >&2
    failure=1
else
    echo "Source scan passed."
fi

if [[ -n "$app_path" ]]; then
    if [[ ! -d "$app_path" || "${app_path##*.}" != "app" ]]; then
        echo "error: expected a built .app directory, received: $app_path" >&2
        exit 2
    fi

    executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Info.plist")"
    executable_path="$app_path/$executable_name"
    if [[ ! -f "$executable_path" ]]; then
        echo "error: app executable not found at: $executable_path" >&2
        exit 2
    fi

    echo "Checking Release executable strings for Debug fixtures and mock identifiers..."
    strings_out="$(mktemp)"
    if ! strings -a "$executable_path" >"$strings_out"; then
        echo "error: could not read strings from $executable_path" >&2
        rm -f "$strings_out"
        exit 3
    fi
    if [[ ! -s "$strings_out" ]]; then
        echo "error: strings produced no output for $executable_path - refusing to call that a pass" >&2
        rm -f "$strings_out"
        exit 3
    fi
    echo "  (scanned $(wc -l <"$strings_out" | tr -d ' ') strings from $executable_name)"
    if rg_scan --line-number --regexp "$release_forbidden" "$strings_out"; then
        echo "error: non-production marker was found in the Release executable" >&2
        failure=1
    else
        echo "Release executable scan passed."
    fi
    rm -f "$strings_out"
elif (( require_app )); then
    echo "error: --require-app was set but no .app path was provided." >&2
    echo "       The Release executable scan is mandatory in the release path." >&2
    exit 2
else
    echo "WARNING: Release executable scan SKIPPED (no .app given)." >&2
    echo "         Source-only verification does NOT prove #if DEBUG code was" >&2
    echo "         compiled out. Run with a Release .app, or --require-app to enforce." >&2
fi

if (( failure != 0 )); then
    exit 1
fi

echo "Release-content verification passed."
