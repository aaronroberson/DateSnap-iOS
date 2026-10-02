# DateSnap Wave 2 Handoff

Updated: 2026-09-29

## Implemented in the repository

- Created `DateSnap.xcodeproj` with:
  - `DateSnap` iOS application target (`com.apple.product-type.application`).
  - `DateSnapTests` unit-test target.
  - iOS 18.0 deployment target and Swift 6 settings.
  - Debug and Release configurations backed by `Config/DateSnap-Debug.xcconfig` and `Config/DateSnap-Release.xcconfig`.
  - Shared `DateSnap` scheme with `DateSnap.storekit` attached to the Run action.
  - `Info.plist`, `DateSnap.entitlements`, `PrivacyInfo.xcprivacy`, and the asset catalog bound to the app target.
- Added `project.yml` as the reproducible XcodeGen source for the project. Regenerate with `xcodegen generate --spec project.yml` after changing target membership or build configuration.
- Added `Assets.xcassets` with:
  - A 1024×1024 `AppIcon` master PNG.
  - A Display-P3 `AccentColor` matching DateSnap primary cyan (`#7CFFEA`).
- Verified the existing Wave 2 application wiring already includes:
  - `PhotosPicker` import in `HomeEmptyStateView` and scan routing through `ScanViewModel`.
  - `EventReviewEditView` backed by `EventReviewViewModel` for Calendar, Reminders, local-notification, and SwiftData writes.
  - StoreKit product loading, purchase, entitlement refresh, and restore calls through `PurchaseViewModel` and `SubscriptionService` in both paywalls.
  - On-device archive copy (`TEMPORAL LOG • ON-DEVICE`) with no cloud-sync claim.

## Validation completed

- `xcodebuild -project DateSnap.xcodeproj -list` identifies:
  - Targets: `DateSnap`, `DateSnapTests`.
  - Configurations: `Debug`, `Release`.
  - Shared scheme: `DateSnap`.
- All release plists pass `plutil -lint`:
  - `Info.plist`
  - `DateSnap.entitlements`
  - `PrivacyInfo.xcprivacy`
  - `ExportOptions-AppStore.plist`
- App icon dimensions verified as exactly 1024×1024.
- A no-signing device build created `DateSnap.app`, processed `Info.plist`, and began compiling the complete iOS source set. Full compilation could not finish in the coding-assistant sandbox because Apple SwiftUI/SwiftData macro plugins were denied by `sandbox-exec` (`swift-plugin-server produced malformed response`). This is an environment restriction; rerun the build normally in Xcode as the first manual check below.

## Outstanding tasks requiring owner access or manual execution

### Before Internal TestFlight

- [ ] Open `DateSnap.xcodeproj` (not `Package.swift`) in Xcode and select the shared `DateSnap` scheme.
- [ ] Replace `YOUR_TEAM_ID` in both `Config/DateSnap-Debug.xcconfig` and `Config/DateSnap-Release.xcconfig` with the Apple Developer Team ID.
- [ ] Register the explicit App ID `com.datesnap.app` in Apple Developer Certificates, Identifiers & Profiles and enable In-App Purchase.
- [ ] Confirm an Apple Distribution certificate is available and let Xcode manage signing automatically.
- [ ] Create the App Store Connect app record:
  - Name: `DateSnap: Screenshot to Calendar`
  - Bundle ID: `com.datesnap.app`
  - SKU: `DATESNAP-IOS-01`
  - Primary language: English (U.S.), unless a different launch locale is desired.
- [ ] Build and run the app in an iOS 18+ simulator from Xcode. Then run the `DateSnapTests` test plan/scheme action.
- [ ] Archive a signed Release build and verify the archive contains `Products/Applications/DateSnap.app`.
- [ ] Replace `YOUR_TEAM_ID` in `ExportOptions-AppStore.plist`, export the IPA, validate it, and upload Build 1 using Xcode Organizer or App Store Connect API credentials.

### Before External TestFlight

- [ ] In App Store Connect, create subscription group `DateSnap Memberships` and these products exactly:
  - `com.datesnap.plus.monthly` — $4.99/month, 7-day free trial.
  - `com.datesnap.plus.annual` — $39.99/year, 7-day free trial.
  - `com.datesnap.premium.monthly` — $8.99/month, no trial.
  - `com.datesnap.premium.annual` — $69.99/year, no trial.
- [ ] Enable the 16-day Billing Grace Period.
- [ ] Create a sandbox tester and verify product loading, purchase, cancellation/expiration downgrade, and restore on a physical iOS 18+ device.
- [ ] Execute every case in `TESTFLIGHT-QA.md` on physical hardware, including denied/limited permissions, ambiguous dates, doors/show times, offline operation, and repetitive OCR memory behavior.
- [ ] Enter the beta review information from `APP-REVIEW-NOTES.md` and submit for Beta App Review.

### Before App Store submission

- [ ] Deploy public HTTPS pages returning HTTP 200:
  - `https://datesnap.app/privacy`
  - `https://datesnap.app/support`
  - `https://datesnap.app`
- [ ] Verify the Terms and Privacy links shown by both paywalls open the final live URLs.
- [ ] Capture and upload 4–6 polished screenshots for:
  - 6.9-inch iPhone: 1320×2868.
  - 6.3-inch iPhone: 1206×2622.
- [ ] Complete the App Privacy questionnaire as `Data Not Collected`.
- [ ] Complete the 4+ age-rating questionnaire and select Utilities as primary category and Productivity as secondary category.
- [ ] Attach all four subscription products, including their review screenshots, to version 1.0.0.
- [ ] Paste the final notes from `APP-REVIEW-NOTES.md` into App Review Information and submit the version for review.

### Before production launch

- [ ] Enable the 7-day automatic phased release after approval.
- [ ] Establish a privacy-compatible production health process. The current product promise is zero telemetry, so do not add a third-party crash or analytics SDK without revisiting the privacy manifest, nutrition label, review copy, and on-device claims. Apple-provided App Store Connect/Xcode Organizer diagnostics are the safest initial option.
- [ ] Brief support personnel and monitor subscription status, reviews, and Apple-provided crash diagnostics during rollout.

## App icon provenance

The master icon was generated with the built-in image-generation tool using the DateSnap design-system palette and a calendar-plus-scan-frame concept. It contains no text, transparency, or external rounded-corner mask. Final asset: `Assets.xcassets/AppIcon.appiconset/DateSnap-AppIcon-1024.png`.
