#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATESNAP_LIVE_AI_DESTINATION:-}" ]]; then
  echo "Set DATESNAP_LIVE_AI_DESTINATION to an xcodebuild destination for a compatible device."
  echo "Example: platform=iOS,id=<device-udid>"
  exit 64
fi

DATESNAP_EVAL_LIVE=1 DATESNAP_REQUIRE_LIVE_AI=1 \
  xcodebuild test \
    -scheme DateSnap \
    -destination "${DATESNAP_LIVE_AI_DESTINATION}" \
    -allowProvisioningUpdates \
    -only-testing:DateSnapTests/AppleIntelligenceLiveTests \
    -only-testing:DateSnapTests/ExtractionEvaluationTests/liveRouteReport
