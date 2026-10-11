#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PENCILD_LIVE_AI_DESTINATION:-}" ]]; then
  echo "Set PENCILD_LIVE_AI_DESTINATION to an xcodebuild destination for a compatible device."
  echo "Example: platform=iOS,id=<device-udid>"
  exit 64
fi

PENCILD_EVAL_LIVE=1 PENCILD_REQUIRE_LIVE_AI=1 \
  xcodebuild test \
    -scheme Pencild \
    -destination "${PENCILD_LIVE_AI_DESTINATION}" \
    -allowProvisioningUpdates \
    -only-testing:PencildTests/AppleIntelligenceLiveTests \
    -only-testing:PencildTests/ExtractionEvaluationTests/liveRouteReport
