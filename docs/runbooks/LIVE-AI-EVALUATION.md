# Live Apple Intelligence Evaluation

## Purpose

The default DateSnap unit-test lane is deterministic and does not invoke a live
Foundation Models session. The two live evaluation tests are kept in a separate
device lane because model availability, latency, and output depend on the OS,
hardware, locale, downloaded model state, and Apple Intelligence settings.

## Required environment

- A physical iOS device and OS version supported by DateSnap's Foundation Models route.
- Apple Intelligence enabled and its model assets fully downloaded.
- The device connected to the Mac running Xcode and visible in `xcrun xctrace list devices`.
- DateSnap signing configured for the device.

## Run the lane

```sh
export DATESNAP_LIVE_AI_DESTINATION='platform=iOS,id=<device-udid>'
scripts/run-live-ai-evaluation.sh
```

The script sets both controls used by the tests:

- `DATESNAP_EVAL_LIVE=1` enables the two opt-in evaluations.
- `DATESNAP_REQUIRE_LIVE_AI=1` converts unavailable model capability into a test
  failure instead of accepting the normal rules-only fallback.

## Pass criteria and evidence

- `AppleIntelligenceLiveTests/livePipeline()` passes and reports the live route.
- `ExtractionEvaluationTests/liveRouteReport()` does not regress date accuracy or
  non-event rejection relative to the deterministic rules baseline.
- Archive the `.xcresult`, device model, OS build, locale, and execution timestamp
  with the release evidence.

## Scheduling

Run this lane before each TestFlight release candidate and after changes to the
understanding pipeline, evidence validator, or Foundation Models integration.
Automated scheduling is **verification required** until the repository has a
registered physical-device CI runner with Apple Intelligence provisioned. The
hosted simulator CI lane must not be treated as evidence that the live model ran.
