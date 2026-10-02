# DateSnap Release Runbook

This runbook outlines the step-by-step procedures for building, archiving, validating, and submitting **DateSnap** to TestFlight and the Apple App Store.

---

## 1. Prerequisites & Environment Setup

1. **Apple Developer Account:** Active Apple Developer Program enrollment with App Manager or Admin role.
2. **Xcode Toolchain:** Xcode 27 with Apple Swift 6.4. Record the exact versions with `xcodebuild -version` and `xcrun swift --version` in the release evidence.
3. **App Store Connect API Key:** (Optional for CI/CD) An App Store Connect API Key with Admin or App Manager access (`AuthKey_XXXXXXXXXX.p8`).
4. **Hardware Testing Devices:** Physical iPhone running iOS 18.0+ for verifying Camera Roll, EventKit, and StoreKit Sandbox flows.

---

## 2. Versioning & Build Numbering Protocol

- **Marketing Version (`CFBundleShortVersionString`):** Semantic versioning (`MAJOR.MINOR.PATCH`, e.g., `1.0.0`).
- **Build Number (`CFBundleVersion`):** Monotonically increasing positive integer (e.g., `1`, `2`, `3`). Every uploaded binary must have a unique build number within the marketing version.
- **Git Tagging:** Tag every release candidate commit:
  ```bash
  git tag -a v1.0.0-b1 -m "Release Candidate 1.0.0 (Build 1)"
  git push origin v1.0.0-b1
  ```

---

## 3. Pre-Flight Verification Checklist

Before archiving:
- [ ] Run test suite: Ensure all unit and inference tests pass.
- [ ] Verify no app-originated telemetry or product-data uploads. Scope traffic inspection to exclude user-initiated web links, Apple Maps links, and StoreKit/App Store system traffic.
- [ ] Verify Privacy Manifest: Check `PrivacyInfo.xcprivacy` presence in the bundle resources.
- [ ] Check Info.plist permissions: Ensure usage strings for Photos, Calendar, and Reminders are present.
- [ ] Verify StoreKit 2 wiring: Confirm paywalls are invoking `SubscriptionService` and not simulation timers.

---

## 4. Archive, Export & Upload Commands

### Step A: Clean & Archive
Set the authorized Apple Developer Team ID in the shell without committing it:

```bash
export DATESNAP_DEVELOPMENT_TEAM="<10-character Team ID>"
test -n "$DATESNAP_DEVELOPMENT_TEAM"
```

```bash
xcodebuild clean archive \
  -project DateSnap.xcodeproj \
  -scheme DateSnap \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "./build/DateSnap.xcarchive" \
  DEVELOPMENT_TEAM="$DATESNAP_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE="Automatic"
```

### Step B: Validate & Export IPA
```bash
xcodebuild -exportArchive \
  -archivePath "./build/DateSnap.xcarchive" \
  -exportPath "./build/Exported" \
  -exportOptionsPlist "./ExportOptions-AppStore.plist"
```

### Step C: Upload to App Store Connect

The preferred interactive workflow is Xcode Organizer: select the archive, choose **Distribute App**, then **App Store Connect → Upload**. This keeps signing and validation feedback visible without putting credentials in shell history.

For automation, Xcode 27 includes `altool`. Confirm it is available with `xcrun altool --help`, then use App Store Connect API-key credentials supplied through the release environment:

```bash
xcrun altool --upload-app \
  -f "./build/Exported/DateSnap.ipa" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
```

Do not commit the `.p8` private key or API credentials. For a manual fallback, use an app-specific password stored in Keychain:

```bash
xcrun altool --upload-app \
  -f "./build/Exported/DateSnap.ipa" \
  -t ios \
  -u "$APPLE_ID" \
  -p "@keychain:ALTOOL_APP_SPECIFIC_PASSWORD"
```

---

## 5. TestFlight Rollout Stages

1. **Internal Testing (Fast Track):**
   - Target: Core team and developers (up to 100 internal testers).
   - Approval: Immediate availability once App Store Connect finishes binary processing (typically 5–15 minutes). No Beta Review needed.
2. **External Beta Testing (Public / Stakeholders):**
   - Target: TestFlight public links or external email groups (up to 10,000 testers).
   - Requirement: Submit build for **Beta App Review** with test notes explaining photo import and privacy guarantees. Review typically clears within 24–48 hours.

---

## 6. App Store Production Submission

1. **App Store Version Information:**
   - Complete screenshots for 6.9" (iPhone 16 Pro Max) and 6.3" (iPhone 16 Pro).
   - Promotional text, description, keywords, support URL, and marketing URL.
   - Privacy Nutrition Label: Select "Data Not Collected" across all categories.
2. **In-App Purchases:**
   - Attach the 4 subscription products (`com.datesnap.plus.monthly`, `com.datesnap.plus.annual`, `com.datesnap.premium.monthly`, `com.datesnap.premium.annual`) to the version submission.
3. **Phased Release:**
   - Enable 7-day automatic phased release to minimize blast radius for unanticipated edge-case issues.
