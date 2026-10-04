#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
source_root="$repo_root/Sources/DateSnap"

source_forbidden='ServiceContainer[.]mock[(]|\bMock[A-Za-z0-9_]*Service\b|mock-(calendar-event|reminder|notification|deadline)-'
release_forbidden='InterpretationDiagnosticsView|ServiceContainer[.]mock|Mock[A-Za-z0-9_]*Service|Mock Rooftop Sunset Party|mock-(calendar-event|reminder|notification|deadline)-|All 17 Stitch Screens|Stitch ID:|Screen State & Simulation Hub|6c145dff8ec540b9a51f806629e55c70'

failure=0

echo "Checking production sources for forbidden mock service code..."
if rg --line-number --glob '*.swift' --regexp "$source_forbidden" "$source_root"; then
    echo "error: production mock service code was found under Sources/DateSnap" >&2
    failure=1
else
    echo "Source scan passed."
fi

app_path="${1:-}"
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
    if strings -a "$executable_path" | rg --line-number --regexp "$release_forbidden"; then
        echo "error: non-production marker was found in the Release executable" >&2
        failure=1
    else
        echo "Release executable scan passed."
    fi
else
    echo "Release executable scan skipped; pass the path to a Release .app to enable it."
fi

if (( failure != 0 )); then
    exit 1
fi

echo "Release-content verification passed."
