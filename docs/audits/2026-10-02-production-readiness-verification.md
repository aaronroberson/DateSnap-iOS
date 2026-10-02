# DateSnap Production Readiness Verification

Date: 2026-10-02

## Candidate configuration verified locally

- XcodeGen 2.46.0 regenerates `DateSnap.xcodeproj` from `project.yml` without a generated-project diff.
- Xcode 27.0 (27A266a) uses Apple Swift 6.4.
- The project exposes the `DateSnap` application target, `DateSnapTests` unit-test target, and shared `DateSnap` scheme.
- Evaluated Release settings resolve to:
  - Product: `DateSnap.app`
  - Bundle identifier: `com.datesnap.app`
  - Marketing version/build: `1.0.0 (1)`
  - Minimum deployment target: iOS 18.0
  - Info plist: `Info.plist`
  - Entitlements: `DateSnap.entitlements`
  - Swift optimization: `-O`
  - Testability: disabled
  - Product validation: enabled
- `Info.plist`, `DateSnap.entitlements`, `PrivacyInfo.xcprivacy`, and `ExportOptions-AppStore.plist` pass `plutil -lint`.
- The app icon is 1024×1024 RGB with no alpha channel.

## Automated tests

The Xcode `DateSnap` test plan completed with 43 discovered tests:

- Passed: 41
- Failed: 0
- Skipped: 2

The skipped tests are the explicitly opt-in live Foundation Models evaluations guarded by `DATESNAP_EVAL_LIVE=1`. They require compatible Apple Intelligence hardware/runtime and must be run or formally dispositioned before release approval.

## Privacy and capability reconciliation

- Repository scanning found no `URLSession`, socket, analytics, crash-reporting, or telemetry client in the app target.
- The app does expose user-initiated HTTPS, Apple Maps, policy/support, and StoreKit flows; release claims and traffic tests must distinguish these from app-originated data upload.
- The required-reason API inventory found `UserDefaults`, matching `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` in the privacy manifest.
- The four StoreKit product identifiers match between `SubscriptionService` and `DateSnap.storekit`.
- Notifications are local. No push, iCloud, app-group, or associated-domain capability was found, so the empty app entitlements dictionary is consistent with the repository-visible feature set.

## Remediations applied

- Removed committed placeholder Team IDs. Developers select a team in Xcode; release automation passes `DEVELOPMENT_TEAM` from the authorized environment.
- Removed the placeholder `teamID` from export options so automatic export can use the archive's signing team.
- Updated release commands for the installed Xcode/Swift toolchain and credential-safe upload variables.
- Corrected Photos-denial QA expectations to match the actual alert and system-picker fallback.
- Scoped offline and traffic claims around the core on-device workflow, StoreKit, and user-initiated links.
- Added an evidence record section to the TestFlight checklist.

## External release blockers

These items cannot be completed from repository access alone:

- Confirm `com.datesnap.app` registration and the authorized Apple Developer Team ID.
- Confirm that App Store Connect version/build `1.0.0 (1)` is unused and reserve or increment it.
- Confirm the product decision to retain iOS 18.0 as the minimum supported version.
- Compare the four subscriptions, trials, pricing, localization, and subscription group against App Store Connect.
- Run the opt-in live Foundation Models evaluation on compatible hardware.
- Produce and inspect a signed archive, provisioning profile, signed entitlements, exported IPA, dSYM, and checksums.
- Upload the exact IPA and complete physical-device TestFlight QA, Instruments checks, scoped traffic observation, URL verification, and App Review metadata.

The release remains **no-go** until these external blockers and the subscription-entitlement audit's required pre-release findings are resolved against one clean, immutable candidate commit.
