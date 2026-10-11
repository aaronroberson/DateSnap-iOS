# Pencil'd Project Handoff

Updated: 2026-10-10

## Current project map

- XcodeGen input: [`project.yml`](project.yml)
- Generated project and shared scheme: [`Pencild.xcodeproj`](Pencild.xcodeproj/), scheme `Pencild`
- SwiftPM/Xcode package manifest: [`Package.swift`](Package.swift)
- App sources: [`Sources/Pencild/`](Sources/Pencild/)
- Tests: [`Tests/PencildTests/`](Tests/PencildTests/)
- Build settings: [`Config/Pencild-Base.xcconfig`](Config/Pencild-Base.xcconfig), [`Config/Pencild-Debug.xcconfig`](Config/Pencild-Debug.xcconfig), [`Config/Pencild-Release.xcconfig`](Config/Pencild-Release.xcconfig)
- Signing entitlements: [`Pencild.entitlements`](Pencild.entitlements)
- Local StoreKit configuration: [`Pencild.storekit`](Pencild.storekit)
- App icon catalog: [`Assets.xcassets/AppIcon.appiconset/Contents.json`](Assets.xcassets/AppIcon.appiconset/Contents.json); Icon Composer source: [`Pencild.icon/`](Pencild.icon/)

## Local identity and subscription configuration

- Display name: `Pencil'd`
- App bundle ID: `com.pencild.app`; test bundle ID: `com.pencild.app.tests`
- Local subscription IDs: `com.pencild.plus.monthly`, `com.pencild.plus.annual`, `com.pencild.premium.monthly`, and `com.pencild.premium.annual`
- Local StoreKit prices: Plus $3.99/month or $24.99/year; Premium $6.99/month or $39.99/year. The local file configures a seven-day introductory offer for all four products.
- These are repository-local values only. App Store Connect registration, live product/price/trial parity, legal name, domain ownership, and publication approval have not been verified.
- The customer-facing tier labels are `Pencil'd Free`, `Pencil'd Plus`, and `Pencil'd Premium`.

## Generate, build, and test

```sh
xcodegen generate --spec project.yml
xcodebuild -list -project Pencild.xcodeproj
xcodebuild -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Use `xcrun simctl list devices available` to choose an installed simulator. Update `project.yml` first when changing target membership, paths, configurations, or scheme StoreKit attachment; then regenerate and review the generated project diff.

## Rename verification recorded for this handoff

- `xcodebuild -list -project Pencild.xcodeproj` reports app/test targets `Pencild` / `PencildTests` and shared scheme `Pencild`.
- `xcodebuild test -project Pencild.xcodeproj -scheme Pencild -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` completed successfully on 2026-10-10.
- A simulator build completed successfully immediately before the project rename was checked. Re-run the explicit build command above after any generated-project or source changes.
- Asset catalog filenames resolve in `Contents.json`. Check icon rendering across supported iOS versions/appearances before release; a successful build alone does not establish visual correctness.

## Remaining owner/account checks

- Confirm App Store Connect has the intended app record, bundle ID, subscription IDs, group, prices, and trials before release.
- Confirm legal/support URLs and mailbox ownership; the current app still points to the existing `pencild.app` endpoints.
- Review resolved icon assets in the built app and test actual permission/review/purchase flows on supported simulator/device configurations.
- Do not upload, deploy, or submit without separate explicit authorization.
