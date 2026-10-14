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
- Local subscription IDs: `com.pencild.plus.monthly`, `com.pencild.plus.annual`, `com.pencild.premium.monthly`, and `com.pencild.premium.annual`; lifetime non-consumables `com.pencild.plus.lifetime` and `com.pencild.premium.lifetime` (added 2026-10-13)
- Local StoreKit prices: Plus $3.99/month, $24.99/year, or $39.99 lifetime; Premium $6.99/month, $39.99/year, or $79.99 lifetime. The local file configures a seven-day introductory offer for the four subscriptions; lifetime is offered in the app through 2027-04-13.
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
- Confirm legal/support URLs and mailbox ownership: the app uses `https://getpencild.com/privacy`, `https://getpencild.com/support`, and `support@getpencild.com` (updated 2026-10-13; `pencild.com` and `pencild.app` belong to someone else). Those pages and the mailbox must be live before release.
- Review resolved icon assets in the built app and test actual permission/review/purchase flows on supported simulator/device configurations.
- Do not upload, deploy, or submit without separate explicit authorization.
