# DateSnap: Wave 2 Release Planning & Launch Execution Plan

**Date:** 2026-09-29  
**Status:** Approved for Implementation  
**Scope:** Wave 2 Packaging, Xcode Projectization, Signing, Capabilities, StoreKit Configuration, TestFlight Rollout, and App Store Submission  

---

## 1. Executive Summary

Wave 1 established DateSnap’s algorithmic core, SwiftData entities, protocol-driven services, and foundational configuration assets (`Info.plist`, `PrivacyInfo.xcprivacy`, `DateSnap.storekit`, `DateSnap.entitlements`, and `Config/`).

**Wave 2 is the distribution, packaging, code signing, TestFlight, and App Store launch operation.** Currently, the app cannot be uploaded to TestFlight or submitted to the App Store due to five primary launch blockers:

1. **Projectization Mismatch:** The repository remains in a pure SwiftPM structure (`Package.swift`). When archived via `xcodebuild`, an SPM `.executableTarget` produces a UNIX Mach-O command-line binary at `/usr/local/bin/DateSnap`, not an iOS Application Bundle (`DateSnap.app`) inside an `.xcarchive`. A concrete `DateSnap.xcodeproj` target must be materialized.
2. **Missing Asset Catalog & App Icon:** The repository lacks an `Assets.xcassets` catalog containing the mandatory 1024×1024 App Store icon asset. Without it, App Store Connect binary validation immediately rejects the upload.
3. **Pending Developer Portal & App Store Connect Provisioning:** The App ID (`com.datesnap.app`), In-App Purchase capability, Subscription Group (`DateSnap Memberships`), and the 4 subscription products are defined in code and local configs, but do not yet exist in the live Apple Developer portal or App Store Connect.
4. **Unwired UI Gating & QA Failures:** The views still use dummy timers (`Task.sleep`) and mock arrays in `AppState.swift`. Distributing the app in this state will fail the manual QA verification gates defined in `TESTFLIGHT-QA.md`.
5. **External Legal/Web URL Dependencies:** Apple Review mandates live, public HTTPS endpoints for the **Privacy Policy URL** and **Support URL**. Submitting placeholder URLs guarantees immediate review rejection.

---

## 2. Release Baseline from Attached Docs

The release documentation suite establishes the following non-negotiable operational requirements:

* **QA Pass Conditions (`TESTFLIGHT-QA.md`):**
  * **Permissions:** Photo Library (read/limited), Apple Calendar (full access), Apple Reminders (full access), and Local Notifications must prompt natively with branded usage descriptions and fail gracefully if denied.
  * **Engine Accuracy:** Concert flyers, ambiguous dates (`04/05/2026`), and doors/show times must extract accurately without cloud processing.
  * **StoreKit Sandbox:** Four active subscription tiers, working 7-day free trial on Plus, entitlement verification via `Transaction.currentEntitlements`, working restore purchases, and graceful downgrade upon cancellation.
  * **Offline Resilience:** 100% of core flyer scanning and calendar/reminder creation must work in Airplane Mode (zero network activity).
* **Privacy & Air-Gapped Claims (`APP-REVIEW-NOTES.md`):**
  * 100% on-device Vision OCR and NaturalLanguage processing.
  * Zero remote telemetry, zero analytics trackers, and "Data Not Collected" declared on the App Store Nutrition Label.
* **StoreKit Expectations (`RELEASE.md`):**
  * 4 specific subscription identifiers: `com.datesnap.plus.monthly`, `com.datesnap.plus.annual`, `com.datesnap.premium.monthly`, `com.datesnap.premium.annual`.
  * Subscription Group: `DateSnap Memberships`.
* **Versioning & Build Numbering:**
  * Marketing Version: `1.0.0` (Semantic `MAJOR.MINOR.PATCH`).
  * Build Number: Monotonically increasing integer (`1`, `2`, `3`...).
* **App Review Metadata Dependencies:**
  * Live Support URL, Privacy Policy URL, and Marketing URL.
  * 6.9" (iPhone 16 Pro Max) and 6.3" (iPhone 16 Pro) App Store screenshots.
  * Reviewer notes explaining the local-only scanning model.

---

## 3. Repo-to-Release Gap Analysis

| Item / Dimension | Target Baseline Requirement | Actual Repository State | Status | Risk / Gap Severity |
|---|---|---|---|---|
| **Xcode Project Structure** | `DateSnap.xcodeproj` with iOS Application product type (`.app`). | Pure `Package.swift` with `.executableTarget`. No `.xcodeproj` exists. | **Missing** | **Showstopper:** Cannot produce `.xcarchive` or `.ipa`. |
| **Info.plist** | Production usage descriptions for Photos, Calendar, Reminders, and encryption flags. | `Info.plist` written to disk with all required keys. | **Confirmed Ready** | Ready to be bound to Xcode project target. |
| **Entitlements** | Standard sandbox entitlements matching local capabilities. | `DateSnap.entitlements` created. | **Confirmed Ready** | Ready. |
| **Apple Privacy Manifest** | `PrivacyInfo.xcprivacy` with zero tracking and Required Reason `CA92.1`. | `PrivacyInfo.xcprivacy` created on disk. | **Confirmed Ready** | Mandatory compliance satisfied. |
| **Asset Catalog & AppIcon** | `Assets.xcassets` with 1024×1024 PNG App Store icon. | No `.xcassets` found in repository. | **Missing** | **Showstopper:** Archive export/upload rejected without AppIcon. |
| **StoreKit Configuration** | Local testing `.storekit` with 4 products and 1 group. | `DateSnap.storekit` written with full tier metadata. | **Confirmed Ready** | Ready for Xcode Scheme binding. |
| **Export Options Plist** | Plist configuring automatic App Store export. | `ExportOptions-AppStore.plist` created. | **Confirmed Ready** | Ready (requires `YOUR_TEAM_ID` replacement). |
| **Build Settings Configuration** | Split Base/Debug/Release `.xcconfig` files. | `Config/` populated with modular settings. | **Confirmed Ready** | Ready. |
| **StoreKit Service Code** | StoreKit 2 manager handling the 4 target IDs. | `SubscriptionService.swift` fully implemented. | **Confirmed Ready** | Code ready; UI calls must be connected. |
| **Air-Gapped Privacy Code** | Zero remote networking (`URLSession`, `URLRequest`). | Audited: 0 network calls across `Sources/`. | **Confirmed Ready** | Backs App Review claims 100%. |
| **View-to-Service Wiring** | Paywalls, scanning, and review save to real services. | UI uses `Task.sleep` simulations and in-memory arrays. | **Partially Ready** | **QA Blocker:** Fails `TESTFLIGHT-QA.md` gates. |
| **Apple Developer Portal** | App ID with IAP, certificates, and profiles. | Not yet configured on developer.apple.com. | **Missing** | Required before signing archive. |
| **App Store Connect Entities** | App record, subscription products, legal URLs. | Not yet configured in App Store Connect. | **Missing** | Required before TestFlight upload. |

---

## 4. Packaging and Project Readiness

### The Projectization Imperative
In SwiftPM, an executable target (`.executableTarget(name: "DateSnap", path: "Sources/DateSnap")`) is designed for command-line utilities. When built for an iOS device destination with the `archive` action:
```
GenerateDSYMFile .../InstallationBuildProductsLocation/usr/local/bin/DateSnap
Strip .../InstallationBuildProductsLocation/usr/local/bin/DateSnap
```
Xcode installs the output as an unbundled binary in `/usr/local/bin/DateSnap`. It does **not** create a signed `DateSnap.app` bundle inside a `Products/Applications/` directory of the archive. Therefore:
- `xcodebuild -exportArchive` fails immediately because no iOS application bundle exists.
- Provisioning profiles cannot be embedded.
- `Info.plist`, asset catalogs, and privacy manifests cannot be packaged.

### Required Xcode Project Specification
We must materialize `DateSnap.xcodeproj` with the following configuration:
* **Project Name:** `DateSnap.xcodeproj`
* **Main Target:** `DateSnap` (Product Type: `com.apple.product-type.application`)
* **Bundle Identifier:** `com.datesnap.app` (or user’s registered reverse-DNS)
* **Deployment Target:** `iOS 18.0`
* **Swift Language Mode:** `Swift 6` with `ApproachableConcurrency` enabled
* **Source Files Attached:** All files under `Sources/DateSnap/`
* **Configurations:**
  * `Debug`: Inherits `Config/DateSnap-Debug.xcconfig`
  * `Release`: Inherits `Config/DateSnap-Release.xcconfig`
* **Resource Bundle Files Attached:**
  * `Info.plist` (Target Info.plist File)
  * `DateSnap.entitlements` (Code Sign Entitlements)
  * `PrivacyInfo.xcprivacy` (Copy Bundle Resources)
  * `Assets.xcassets` (AppIcon & AccentColor)
* **Test Target:** `DateSnapTests` attaching `Tests/DateSnapTests/`

---

## 5. Signing and Provisioning Plan

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                SIGNING & PROVISIONING ARCHITECTURE                      │
│                                                                                         │
│  [developer.apple.com]                                                                  │
│    ├── 1. Register App ID: com.datesnap.app (Enable In-App Purchase)                     │
│    └── 2. Distribution Certificate: Apple Distribution: Your Team (10-char Team ID)    │
│                                                                                         │
│  [Xcode Project Settings]                                                               │
│    ├── Automatic Signing: Enabled                                                       │
│    ├── Team: Selected (YOUR_TEAM_ID)                                                    │
│    └── Bundle ID: com.datesnap.app                                                      │
│                                                                                         │
│  [App Store Connect]                                                                    │
│    ├── App Record Created (SKU: DATESNAP-IOS-01)                                        │
│    └── TestFlight builds receive automated App Store Managed Re-signing upon upload    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Division of Responsibility

#### 1. In `developer.apple.com` (Certificates, Identifiers & Profiles):
1. **Identifiers > App IDs > Register an App ID:**
   * **App Type:** App
   * **Description:** DateSnap iOS
   * **Bundle ID:** Explicit -> `com.datesnap.app`
   * **Capabilities:** Check **In-App Purchase** (mandatory for StoreKit 2 receipt validation).
2. **Certificates:** Generate an **Apple Distribution** certificate if one does not already exist for the team.

#### 2. In Xcode:
1. **Signing & Capabilities:**
   * Set **Signing Style** to **Automatic** (`CODE_SIGN_STYLE = Automatic`).
   * Select your **Team** (`DEVELOPMENT_TEAM = YOUR_TEAM_ID`).
   * Xcode automatically creates and manages the `iOS Team Provisioning Profile: com.datesnap.app` and downloads the distribution certificate.

#### 3. In App Store Connect:
* Upon upload via `xcrun altool`, Apple’s ingestion pipeline validates the signature against the App ID, strips the development provisioning profile, and applies the official App Store / TestFlight DRM signature.
* **Notarization:** Irrelevant for iOS (macOS only).

---

## 6. Capabilities, Permissions, and Privacy

### Capability & Privacy Compliance Matrix

| Subsystem / API | Code Evidence | Apple Capability | Info.plist Key | Entitlement Needed? | Privacy Manifest Declaration | App Review Sensitivity |
|---|---|---|---|---|---|---|
| **Photo Library** | `PhotoLibraryService.swift:31` (`PHPhotoLibrary`) | Photos | `NSPhotoLibraryUsageDescription` | No | None (photos stay local) | **High:** Reviewers check for local processing justification. |
| **Calendar Sync** | `CalendarService.swift:29` (`EKEventStore`) | EventKit | `NSCalendarsFullAccessUsageDescription` & `NSCalendarsUsageDescription` | No | None | **High:** Must clarify save occurs only on user tap. |
| **Reminders Alerts** | `ReminderService.swift:57` (`EKEventStore`) | EventKit | `NSRemindersFullAccessUsageDescription` & `NSRemindersUsageDescription` | No | None | **Medium:** Explained in review notes. |
| **Local Alerts** | `NotificationService.swift:37` (`UNUserNotificationCenter`) | UserNotifications | *None* | No (Local notifications only) | None | **Low:** Handled via system prompt. |
| **Vision OCR** | `OCRService.swift:15` (`VNRecognizeTextRequest`) | Vision | *None* | No | None | **Zero:** Pure local CPU/Neural Engine framework. |
| **Temporal NLP** | `EventExtractionService.swift` (`NSDataDetector`) | NaturalLanguage | *None* | No | None | **Zero:** 100% on-device heuristic engine. |
| **StoreKit 2** | `SubscriptionService.swift:42` (`StoreKit`) | In-App Purchase | *None* | Yes (App ID capability) | None | **High:** Subscription disclosures & restore required. |
| **User Defaults** | `SettingsState.swift` (`@AppStorage`) | Foundation | *None* | No | Category: `UserDefaults`<br>Reason: `CA92.1` | **Mandatory:** Apple requires reason `CA92.1` since May 2024. |

### Verification of Privacy Claims
* **Air-Gapped Claim:** Code audit confirms **zero occurrences** of `URLSession`, `URLRequest`, `URLCache`, or socket networking in `Sources/`. The claim of "Zero-Cloud Extraction, 100% On-Device" is 100% truthful.
* **Data Nutrition Label Claim:** Because no data is collected off the device, the App Store Nutrition Label must be marked as **"Data Not Collected"**.
* **Resolved Copy Contradiction:** `HistoryArchiveView.swift` line 30 previously read `"TEMPORAL LOG • CLOUD SYNCED"`. This must be updated to `"TEMPORAL LOG • LOCAL ARCHIVE"` before submission to prevent rejection under Guideline 2.3.

---

## 7. StoreKit & Subscription Release Plan

### 1. App Store Connect Product Alignment
The exact four product identifiers from `SubscriptionService.swift:54-59` and `DateSnap.storekit` must be registered in App Store Connect:

```
Subscription Group: "DateSnap Memberships" (Group ID: 21589001)
├── Tier 1 (Top Level): DateSnap Premium
│   ├── com.datesnap.premium.annual  ($69.99 / year)  [No Trial]
│   └── com.datesnap.premium.monthly ($8.99 / month)  [No Trial]
└── Tier 2 (Standard): DateSnap Plus
    ├── com.datesnap.plus.annual     ($39.99 / year)  [Introductory Offer: 7-Day Free Trial]
    └── com.datesnap.plus.monthly    ($4.99 / month)  [Introductory Offer: 7-Day Free Trial]
```

### 2. Operational Verification Stages
1. **Local StoreKit Simulation (`DateSnap.storekit`):**
   - Bind scheme to `DateSnap.storekit`.
   - Test transactions, instant purchases, renewal acceleration, and billing failure simulations without internet access.
2. **App Store Connect Sandbox Testing:**
   - Create a Sandbox Tester account in App Store Connect (Users and Access > Sandbox Testers).
   - Sign in via Settings > Developer > Sandbox Apple Account on a physical iPhone running iOS 18+.
   - Test real StoreKit 2 sheet presentation, StoreKit receipt cryptographic verification, and the 7-day introductory trial.
3. **Billing Retry & Grace Period:**
   - In App Store Connect, turn ON **Billing Grace Period** (16 days for monthly/annual).
4. **Attaching Subscriptions to App Submission:**
   - When submitting version 1.0.0 for review, you **must explicitly attach the subscription products** in the version submission page under **In-App Purchases and Subscriptions**. If omitted, reviewers cannot purchase the products and will reject the app under Guideline 2.1.

---

## 8. TestFlight Rollout Plan

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 TESTFLIGHT STAGES                                      │
│                                                                                        │
│  [Build Upload] ──> [Processing (5-15m)] ──> [Stage 1: Internal TestFlight]            │
│                                                    │ (Pass Gate 1)                     │
│                                                    ▼                                   │
│                                              [Beta App Review]                         │
│                                                    │ (12-24h approval)                 │
│                                                    ▼                                   │
│                                              [Stage 2: External TestFlight]            │
│                                                    │ (Pass Gate 2)                     │
│                                                    ▼                                   │
│                                              [Stage 3: App Store Production Submission]│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Stage 1: Internal TestFlight (Team & Core Stakeholders)
* **Access:** Up to 100 internal users. No Apple review required.
* **Gate 1 (Internal Pass Criteria):**
  - Binary compiles with whole-module optimization and zero warnings.
  - App launches without crashing; SwiftData container initializes cleanly.
  - Basic flyer selection processes through Vision OCR without hanging.
  - Restore purchases executes without UI freeze.

### Stage 2: External TestFlight (Public Link & Beta Testers)
* **Access:** Up to 10,000 external users.
* **Requirement:** Requires **Beta App Review**.
* **Review Notes for Beta:** Include the exact text from `APP-REVIEW-NOTES.md`, specifically explaining that the app requests Photo Library read access to scan screenshot flyers locally.
* **Gate 2 (External Pass Criteria):**
  - All test cases in `TESTFLIGHT-QA.md` pass on physical hardware.
  - Crash-free rate > 99.5%.
  - Zero memory leaks observed during repetitive Vision OCR sessions.

### Stage 3: App Store Submission Gate
* **Gate 3 (Production Go/No-Go):**
  - External beta feedback incorporated.
  - StoreKit sandbox purchase, restore, and expiration verified.
  - All legal URLs, privacy labels, and marketing screenshots finalized.

---

## 9. App Review & Metadata Readiness

### Metadata Assets Checklist

| Metadata Item | Target Specification | Status | Action Required |
|---|---|---|---|
| **App Name** | `DateSnap: Screenshot to Calendar` | Drafted | Enter into App Store Connect. |
| **Subtitle** | `On-Device Flyer & Event Sync` | Drafted | Enter into App Store Connect. |
| **Primary Category** | `Utilities` | Defined | Select in App Store Connect. |
| **Secondary Category** | `Productivity` | Defined | Select in App Store Connect. |
| **Privacy Policy URL** | `https://datesnap.app/privacy` | **Blocked** | Must be deployed to public web. |
| **Support URL** | `https://datesnap.app/support` | **Blocked** | Must be deployed to public web. |
| **Marketing URL** | `https://datesnap.app` | **Blocked** | Must be deployed to public web. |
| **Age Rating** | `4+` | Defined | Complete questionnaire in Connect. |
| **Data Nutrition Label** | `Data Not Collected` | Defined | Check all categories as Not Collected. |
| **Screenshots (6.9")** | iPhone 16 Pro Max (1320 × 2868 px) | Missing | Capture 4–6 screens from Simulator. |
| **Screenshots (6.3")** | iPhone 16 Pro (1206 × 2622 px) | Missing | Capture 4–6 screens from Simulator. |
| **In-App Disclosures** | Terms of Use & Privacy Policy links on Paywalls | In UI | Verify links open Safari sheets cleanly. |
| **Reviewer Notes** | Rationale for Photos/Calendar access | Drafted in `APP-REVIEW-NOTES.md` | Copy into App Review Notes field. |

---

## 10. Build, Archive, Export, and Upload Plan

### Corrected, Truthful Build Commands

Once `DateSnap.xcodeproj` is established, execute these commands from the repository root:

#### Step 1: Clean & Build Verification
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild clean build \
  -project DateSnap.xcodeproj \
  -scheme DateSnap \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug
```

#### Step 2: Production Archive
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild clean archive \
  -project DateSnap.xcodeproj \
  -scheme DateSnap \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath './build/DateSnap.xcarchive' \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  CODE_SIGN_STYLE="Automatic"
```

#### Step 3: Export IPA
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -exportArchive \
  -archivePath './build/DateSnap.xcarchive' \
  -exportPath './build/Exported' \
  -exportOptionsPlist './ExportOptions-AppStore.plist'
```

#### Step 4: Validate and Upload via `xcrun altool`
Using App Store Connect API Key (recommended):
```bash
# Validate IPA against App Store rules
xcrun altool --validate-app \
  -f "./build/Exported/DateSnap.ipa" \
  -t ios \
  --apiKey "YOUR_API_KEY_ID" \
  --apiIssuer "YOUR_ISSUER_UUID"

# Upload binary to App Store Connect
xcrun altool --upload-app \
  -f "./build/Exported/DateSnap.ipa" \
  -t ios \
  --apiKey "YOUR_API_KEY_ID" \
  --apiIssuer "YOUR_ISSUER_UUID"
```

---

## 11. Wave 2 Task Plan

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   WAVE 2 EXECUTION TIERS                               │
│                                                                                        │
│   P0: Internal TestFlight ──> P1: External Beta ──> P2: Submission ──> P3: Launch Day  │
│   (Project & Assets)          (QA & Connect IAPs)   (Metadata & URLs)  (Phased Release)│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### P0 — Required Before Internal TestFlight
* **Task 0.1 (Projectization):** Materialize `DateSnap.xcodeproj` targeting iOS 18 with configurations mapped to `Config/*.xcconfig`. *(Owner: Xcode Config / Code)*
* **Task 0.2 (Asset Catalog):** Create `Assets.xcassets` with 1024×1024 App Store AppIcon. *(Owner: Design / Xcode Config)*
* **Task 0.3 (App ID Registration):** Register App ID `com.datesnap.app` on `developer.apple.com` with In-App Purchase enabled. *(Owner: Apple Portal)*
* **Task 0.4 (App Store Connect App Record):** Create app record in App Store Connect with Primary Language and SKU. *(Owner: App Store Connect)*
* **Task 0.5 (Archive & Upload Build 1):** Execute archive, export, and upload via `altool` for internal team testing. *(Owner: Release Engineer)*

### P1 — Required Before External TestFlight / Beta App Review
* **Task 1.1 (Connect UI to ViewModels):** Wire `HomeEmptyStateView` to `PhotosPicker` and `EventReviewEditView` to `EventReviewViewModel` to satisfy `TESTFLIGHT-QA.md`. *(Owner: Code)*
* **Task 1.2 (App Store Connect Subscriptions):** Configure Subscription Group `DateSnap Memberships` and the 4 products in App Store Connect. *(Owner: App Store Connect)*
* **Task 1.3 (Beta Review Notes):** Populate Beta App Review information using `APP-REVIEW-NOTES.md`. *(Owner: App Store Connect)*
* **Task 1.4 (Sandbox QA Execution):** Execute physical device QA checklist on iOS 18 hardware. *(Owner: QA)*

### P2 — Required Before App Store Submission
* **Task 2.1 (Deploy Legal & Support URLs):** Deploy public HTTPS web pages for Privacy Policy and Support. *(Owner: Marketing / Web / Legal)*
* **Task 2.2 (App Store Screenshots):** Capture and upload 6.9" and 6.3" screenshots to App Store Connect. *(Owner: Marketing / Design)*
* **Task 2.3 (Attach In-App Purchases):** Explicitly attach the 4 subscription products to the 1.0.0 submission version. *(Owner: App Store Connect)*
* **Task 2.4 (Complete Nutrition Label):** Fill out Data Privacy declarations ("Data Not Collected"). *(Owner: App Store Connect)*

### P3 — Required Before Production Launch Day
* **Task 3.1 (Phased Release Configuration):** Enable 7-Day Automatic Phased Release in App Store Connect. *(Owner: Release Manager)*
* **Task 3.2 (Production Health Monitoring):** Establish crash reporting and StoreKit transaction monitoring. *(Owner: Engineering Lead)*

---

## 12. Required Deliverables Checklist

By the conclusion of Wave 2, the following artifacts must exist:

- [ ] `DateSnap.xcodeproj` with application target and active `DateSnap` scheme.
- [ ] `Assets.xcassets/AppIcon.appiconset` with 1024×1024 PNG master icon.
- [ ] Registered App ID `com.datesnap.app` on `developer.apple.com`.
- [ ] Configured Subscription Group and 4 IAP products in App Store Connect.
- [ ] Bound and verified `Info.plist`, `DateSnap.entitlements`, and `PrivacyInfo.xcprivacy`.
- [ ] Signed and exported `DateSnap.ipa` uploaded to App Store Connect.
- [ ] Approved TestFlight Beta build with verified QA test matrix.
- [ ] Live Privacy Policy URL (`https://datesnap.app/privacy`) and Support URL (`https://datesnap.app/support`).
- [ ] Complete App Store version record (screenshots, descriptions, reviewer notes).

---

## 13. Operational Go/No-Go Checklists

### A. Internal TestFlight Go/No-Go
* [ ] Does `xcodebuild archive` produce a valid `.xcarchive` containing `Products/Applications/DateSnap.app`?
* [ ] Does `xcrun altool --validate-app` pass with zero fatal validation errors?
* [ ] Does the uploaded binary process to "Ready to Test" in App Store Connect?
* **Decision:** **GO** to add internal testers.

### B. External TestFlight Go/No-Go
* [ ] Are all test cases in `TESTFLIGHT-QA.md` verified on physical iOS 18 hardware?
* [ ] Are the reviewer notes from `APP-REVIEW-NOTES.md` entered in Beta Review Information?
* [ ] Has Beta App Review approved the build?
* **Decision:** **GO** to enable public link / invite external beta testers.

### C. App Store Submission Go/No-Go
* [ ] Are Privacy Policy and Support URLs live, publicly accessible, and returning HTTP 200?
* [ ] Are the 4 subscription products attached to the version submission with review screenshots?
* [ ] Is "Data Not Collected" completed in App Privacy?
* [ ] Are 6.9" and 6.3" screenshots uploaded for all required locales?
* **Decision:** **GO** to click "Submit for Review".

### D. Production Release Day Go/No-Go
* [ ] Has Apple App Review granted **Approved** status?
* [ ] Is the 7-day phased rollout toggle active?
* [ ] Are support personnel briefed and ready for launch inquiries?
* **Decision:** **GO** to release version 1.0.0.

---

## Answers to Specific Questions

### 1. Is the repository currently in a shape that can actually be archived for iOS release?
**No.** The repository is configured solely as a SwiftPM executable target (`Package.swift`). Running `xcodebuild -scheme DateSnap -destination 'generic/platform=iOS' archive` compiles a UNIX CLI binary to `/usr/local/bin/DateSnap` and does not generate an `.app` bundle or an `.ipa`. A standard `DateSnap.xcodeproj` iOS Application target must be created before archiving is possible.

### 2. Are all required permission strings, entitlements, and privacy-manifest artifacts present?
**Yes, the configuration files are present on disk, but pending target attachment.**
`Info.plist` contains all 5 required permission strings (`NSPhotoLibraryUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSCalendarsUsageDescription`, `NSRemindersFullAccessUsageDescription`, `NSRemindersUsageDescription`), `DateSnap.entitlements` is prepared, and `PrivacyInfo.xcprivacy` declares zero tracking and Required Reason `CA92.1` for `UserDefaults`. Once `DateSnap.xcodeproj` is generated, these files must be bound in build settings.

### 3. Are the subscription products and paywall assumptions consistent with the real code?
**The identifiers are consistent, but UI execution is simulated.**
The four product IDs in the docs (`com.datesnap.plus.monthly`, `com.datesnap.plus.annual`, `com.datesnap.premium.monthly`, `com.datesnap.premium.annual`) match `SubscriptionService.swift:54-59` and `DateSnap.storekit` exactly. However, the paywall views still run `Task.sleep` simulations. They must call `subscriptionService.purchase(product:)` to function in TestFlight and sandbox environments.

### 4. Are the release claims around offline/on-device/privacy supportable by the actual implementation?
**Yes, 100% supportable.**
Code auditing proves zero network calls (`URLSession`, sockets, analytics) exist in `Sources/`. All OCR and inference runs locally on the CPU/Neural Engine. The App Store Nutrition Label claim of "Data Not Collected" and the offline guarantee in `TESTFLIGHT-QA.md` are technically truthful and verified.

### 5. What exact work remains before DateSnap can be safely distributed to internal testers?
1. Create `DateSnap.xcodeproj` pointing to `Sources/DateSnap/` and bind `Config/*.xcconfig`.
2. Add a 1024×1024 AppIcon into `Assets.xcassets`.
3. Register App ID `com.datesnap.app` on `developer.apple.com`.
4. Create the DateSnap app record in App Store Connect.
5. Archive and upload Build 1 via `xcrun altool`.

### 6. What exact additional work remains before external TestFlight and Beta App Review?
1. Wire `PhotosPicker` and `EventReviewViewModel` in the UI to satisfy the test cases in `TESTFLIGHT-QA.md`.
2. Register the 4 subscription products in App Store Connect.
3. Submit the build for Beta App Review with test instructions from `APP-REVIEW-NOTES.md`.

### 7. What exact additional work remains before pressing “Submit for Review” in App Store Connect?
1. Deploy live web pages for the Privacy Policy and Support URLs.
2. Upload 6.9" and 6.3" screenshots.
3. Attach the 4 subscription products to the 1.0.0 submission page.
4. Complete the App Privacy Nutrition Label ("Data Not Collected").
5. Paste the final review notes into the App Review Information section.

### 8. What non-code dependencies remain?
1. **Live URLs:** `https://datesnap.app/privacy` and `https://datesnap.app/support` must be deployed and publicly resolvable.
2. **Graphic Assets:** 1024×1024 master app icon and App Store marketing screenshots.
3. **Apple Account Setup:** Administrative access to Apple Developer and App Store Connect portals for App ID and IAP configuration.
