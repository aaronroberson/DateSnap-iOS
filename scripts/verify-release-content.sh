#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
source_root="$repo_root/Sources/DateSnap"

source_forbidden='ServiceContainer[.]mock[(]|\bMock[A-Za-z0-9_]*Service\b|mock-(calendar-event|reminder|notification|deadline)-'
release_forbidden='InterpretationDiagnosticsView|ServiceContainer[.]mock|Mock[A-Za-z0-9_]*Service|Mock Rooftop Sunset Party|mock-(calendar-event|reminder|notification|deadline)-|All 17 Stitch Screens|Stitch ID:|Screen State & Simulation Hub|Launch Marketing Kit|0[.]12s on-device OCR|auto-purged screenshot storage|6c145dff8ec540b9a51f806629e55c70|sampleNeonSunset|Neon Sunset Rooftop Session|sampleDentalCheckup|Dr. Aris Dental Checkup|sampleSummerMixer|Summer Rooftop Mixer'

# Symbol-table sentinels. Swift stores string literals of <=15 UTF-8 bytes as
# immediates, so they never reach the string table and `strings` cannot see them
# (measured: 14B and 15B absent, 16B present). That makes the release_forbidden
# entry 'Stitch ID:' (10B) structurally undetectable by a strings scan - a check
# that can never fire. These type/property names appear as mangled symbols
# regardless of literal length. Each is verified PRESENT in a Debug build and
# ABSENT from Release, so the assertion can actually fail when it should.
release_forbidden_symbols='ScreenGalleryView|InterpretationDiagnosticsView|rawOcrFragments|stitchId|sampleNeonSunset|sampleDentalCheckup|sampleSummerMixer'

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

    # Xcode 16+ Debug builds place ALL app code in <Name>.debug.dylib and leave
    # CFBundleExecutable as a ~70KB launcher stub. Scanning only CFBundleExecutable
    # would therefore report "passed" for a Debug bundle packed with DEBUG code
    # (measured: launcher 120 symbols vs its dylib 119,161, incl. ScreenGalleryView).
    # So scan every Mach-O in the bundle, not just the declared executable.
    if find "$app_path" \( -name '*.debug.dylib' -o -name '__preview.dylib' \) -print -quit | grep -q .; then
        echo "error: bundle contains a Debug/preview dylib - this is NOT a Release artifact:" >&2
        find "$app_path" \( -name '*.debug.dylib' -o -name '__preview.dylib' \) | sed 's/^/  /' >&2
        failure=1
    fi

    macho_list="$(mktemp)"
    find "$app_path" -type f -print0 \
      | while IFS= read -r -d '' f; do
            # `if` (not `&&`) so a non-Mach-O last file does not make the loop
            # exit nonzero and trip `set -e`.
            if file -b "$f" 2>/dev/null | grep -q 'Mach-O'; then printf '%s\n' "$f"; fi
        done > "$macho_list"
    macho_count="$(wc -l <"$macho_list" | tr -d ' ')"
    if [[ "$macho_count" -eq 0 ]]; then
        echo "error: no Mach-O binary found in $app_path - refusing to call that a pass" >&2
        rm -f "$macho_list"; exit 3
    fi
    echo "Checking $macho_count Mach-O binary(ies) in the bundle..."

    total_strings=0
    while IFS= read -r bin; do
        rel="${bin#"$app_path"/}"
        strings_out="$(mktemp)"
        if ! strings -a "$bin" >"$strings_out"; then
            echo "error: could not read strings from $bin" >&2
            rm -f "$strings_out" "$macho_list"; exit 3
        fi
        s_count="$(wc -l <"$strings_out" | tr -d ' ')"
        total_strings=$((total_strings + s_count))
        syms_out="$(mktemp)"
        nm -a "$bin" >"$syms_out" 2>/dev/null || true
        y_count="$(wc -l <"$syms_out" | tr -d ' ')"
        echo "  [$rel] $s_count strings, $y_count symbols"
        if rg_scan --line-number --regexp "$release_forbidden" "$strings_out"; then
            echo "error: non-production marker found in strings of $rel" >&2
            failure=1
        fi
        # Symbol pass: catches the short markers strings structurally cannot see.
        if [[ -s "$syms_out" ]]; then
            if rg_scan --line-number --regexp "$release_forbidden_symbols" "$syms_out"; then
                echo "error: DEBUG-only symbol found in $rel - #if DEBUG code reached this build" >&2
                failure=1
            fi
        else
            echo "  [$rel] no symbol table (stripped) - strings pass only"
        fi
        rm -f "$strings_out" "$syms_out"
    done <"$macho_list"
    rm -f "$macho_list"

    if (( total_strings < 1000 )); then
        echo "error: only $total_strings strings across the entire bundle - implausibly" >&2
        echo "       few; refusing to pass what is probably the wrong artifact" >&2
        exit 3
    fi
    if (( failure == 0 )); then
        echo "Release artifact scan passed ($macho_count binary(ies), $total_strings strings)."
    fi
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
