# DateSnap Production Readiness Implementation Plan

## 1. Objective

Prepare a reproducible, signed, tested, privacy-compliant DateSnap 1.0.0 release candidate for TestFlight and App Store submission, with every approval artifact tied to one immutable commit and build number. The current audit outcome is **no-go** until all blockers below are resolved and every blocking verification in this plan passes.

## 2. Inputs Reviewed

### Configuration

- `project.yml`
- `Package.swift`
- `Config/DateSnap-Base.xcconfig`
- `Config/DateSnap-Debug.xcconfig`
- `Config/DateSnap-Release.xcconfig`
- `Info.plist`
- `DateSnap.entitlements`
- `ExportOptions-AppStore.plist`
- `DateSnap.storekit`
- Generated project presence and tracked files under `DateSnap.xcodeproj/` via git
- Current branch, working-tree status, and `project.yml` diff via git

### Privacy/compliance

- `PrivacyInfo.xcprivacy`
- `Sources/DateSnap/Services/PhotoLibraryService.swift`
- `Sources/DateSnap/Services/CalendarService.swift`
- `Sources/DateSnap/Services/ReminderService.swift`
- `Sources/DateSnap/Services/NotificationService.swift`
- `Sources/DateSnap/Services/SubscriptionService.swift`
- `Sources/DateSnap/ViewModels/HomeViewModel.swift`
- Repository searches for network APIs/URLs, required-reason APIs, permission requests, and StoreKit product identifiers

### Release process

- `docs/audits/2026-10-01-production-readiness-audit.md`
- `docs/runbooks/RELEASE.md`
- `docs/runbooks/TESTFLIGHT-QA.md`
- `docs/runbooks/APP-REVIEW-NOTES.md`

### Tests

- Test inventory under `Tests/DateSnapTests/`
- `Tests/DateSnapTests/DateSnapTests.swift`
- `Tests/DateSnapTests/AppleIntelligenceLiveTests.swift`

The discovered test inventory also includes `AdvisorTests.swift`, `ExtractionEvaluationTests.swift`, `DateSnapInferenceTests.swift`, `InterpretationRecordTests.swift`, `EventUnderstandingTests.swift`, `EvidenceValidationTests.swift`, and `EventUnderstandingPipelineTests.swift`. These files were inventoried but not individually content-reviewed for this planning pass.

## 3. Executive Summary

DateSnap is structurally close to a releasable candidate, but it cannot ship from the current repository state. The working tree is dirty on `main`; the Release xcconfig and App Store export plist still contain `YOUR_TEAM_ID`; and no passing test, archive, export, or TestFlight QA evidence is tied to a frozen commit. The shortest path is to decide the intended source changes, establish real Release signing/version values, regenerate and validate the Xcode project, reconcile privacy/capabilities and submission claims against the built archive, then freeze, tag, archive, export, upload, and run the existing physical-device QA checklist.

The shared base config already defines `MARKETING_VERSION = 1.0.0` and `CURRENT_PROJECT_VERSION = 1`; the remaining requirement is to confirm those are the effective Release values and are acceptable/unused in App Store Connect. The app declares no tracking or collected data, uses only the UserDefaults required-reason category, and has an empty app entitlements file. Those declarations are plausible from the reviewed source, but remain **verification required** against the final archive and App Store Connect. Local notifications do not require the remote push notification entitlement.

## 4. Blockers

### Blocker 1 — Release candidate is not frozen or reproducible

- **Why it blocks release:** The shipped source cannot map to a reviewed immutable commit while intended and accidental changes are mixed together.
- **Evidence:** Current `main` status shows modified `Assets.xcassets/AppIcon.appiconset/DateSnap-AppIcon-1024.png` and `project.yml`, plus untracked `.freebuff/`, `HANDOFF.md`, and `docs/audits/`. The `project.yml` diff changes assets and the privacy manifest to explicit resource build phases, affecting the shipped bundle.
- **Exact files involved:** The paths above, generated `DateSnap.xcodeproj/`, this plan, and any approved ignore rules. `lancedb/` must remain untouched.
- **Required remediation:** Classify every dirty item as ship, documentation/tooling, ignore, or remove; do not delete untracked content without owner approval; determine the repository's XcodeGen command/version (**verification required**); regenerate and review the project; commit and review the candidate; tag only after all pre-tag gates pass.
- **Verification method:** `git status --short --branch`, `git diff --check`, staged-diff review, `git rev-parse HEAD`, and annotated-tag verification.
- **Exit criteria:** Reviewed commit, empty `git status --porcelain`, synchronized generated project, and annotated `v1.0.0-b<build>` tag resolving to the candidate SHA.

### Blocker 2 — Distribution signing values are placeholders

- **Why it blocks release:** A trustworthy generic-device archive and App Store export cannot use `YOUR_TEAM_ID`.
- **Evidence:** The placeholder exists in both xcconfigs, `ExportOptions-AppStore.plist`, and the archive command in `docs/runbooks/RELEASE.md`.
- **Exact files involved:** `Config/DateSnap-Release.xcconfig`, `Config/DateSnap-Debug.xcconfig`, `ExportOptions-AppStore.plist`, `docs/runbooks/RELEASE.md`, and the Apple account record for `com.datesnap.app`.
- **Required remediation:** Confirm the authorized Team ID and registered App ID (**verification required**); select one documented source of truth; replace/remove all placeholder release paths; never commit credentials or private keys; ensure automatic signing resolves an Apple Distribution identity and App Store profile.
- **Verification method:** Inspect Release `xcodebuild -showBuildSettings`, archive codesign entitlements, and decoded embedded provisioning profile.
- **Exit criteria:** No release placeholder remains; team, bundle ID, archive signature, profile, and export Team ID agree.

### Blocker 3 — No release-candidate build, test, archive, or export evidence

- **Why it blocks release:** Test inventory and runbooks are not proof that the exact candidate is distributable.
- **Evidence:** No passing result was supplied; the smoke test only expects `true`; the live Foundation Models test is disabled unless `DATESNAP_EVAL_LIVE=1`; no archive/export/TestFlight signoff is tied to a SHA.
- **Exact files involved:** `DateSnap.xcodeproj`, `project.yml`, `Tests/DateSnapTests/`, all three release runbooks, and generated release evidence.
- **Required remediation:** Run all automated tests; execute or disposition the opt-in live route; archive and export Release; upload that build; complete critical/high physical-device QA; retain logs, xcresult, metadata, and signoff. Evidence storage location is **verification required** because none is defined.
- **Verification method:** Successful test/archive/export exits, retained artifacts, App Store processing success, and QA checklist mapped to SHA/version/build.
- **Exit criteria:** Tests pass, archive/export succeeds, exact build processes in TestFlight, critical/high QA passes, and release approval is recorded.

## 5. Workstreams

### Release hygiene and source control freeze

- **Goal:** Create one reviewed, reproducible release input.
- **Tasks:** Triage dirty files; protect `lancedb/` and credentials; define XcodeGen ownership; synchronize generated output; commit, review, and tag; record SHA, version, build, Xcode, and Swift versions.
- **Files:** `project.yml`, `DateSnap.xcodeproj/`, app icon, `.gitignore` if approved, audit, plan, and runbooks.
- **Dependencies:** Configuration/compliance work and automated tests must finish before final tagging.
- **Output artifacts:** Clean status, reviewed commit, annotated tag, release manifest.

### Build/versioning/release configuration

- **Goal:** Make effective Release settings explicit and consistent.
- **Tasks:** Reserve version/build; validate `1.0.0 (1)` or update it; retain variable-based Info.plist wiring; decide iOS 18-only support; regenerate project; capture evaluated settings; verify the runbook's Xcode/Swift prerequisite because `Xcode 16.0+ running Swift 6.4` may be internally inconsistent.
- **Files:** `Package.swift`, `project.yml`, base/Release xcconfigs, `Info.plist`, generated project, release runbook.
- **Dependencies:** Product decisions for OS support and version/build.
- **Output artifacts:** Approval record and evaluated Release settings.

### Signing/export/distribution validation

- **Goal:** Produce an App Store-valid archive and IPA.
- **Tasks:** Resolve account/team; align signing sources; archive, validate, export, and inspect; update upload instructions to a currently supported method. The documented `xcrun altool` path is **verification required**.
- **Files:** Release xcconfig, export plist, entitlements, release runbook.
- **Dependencies:** Frozen candidate content, Apple account access, resolved configuration.
- **Output artifacts:** Archive, IPA, dSYM, logs, validation and processing records.

### Privacy manifest and permission compliance

- **Goal:** Align source, final binary, privacy label, prompts, and reviewer claims.
- **Tasks:** Inventory required-reason APIs and linked manifests; confirm `CA92.1`; inspect archive privacy output; validate no tracking/reportable collection; distinguish user-initiated links and StoreKit from product-data upload; verify permission states and encryption declaration.
- **Files:** Privacy manifest, Info.plist, reviewed permission/service files, QA and App Review runbooks.
- **Dependencies:** Final dependency graph and near-final archive.
- **Output artifacts:** Privacy reconciliation, archive report, permission evidence, approved privacy answers.

### Entitlements and capabilities reconciliation

- **Goal:** Prove the empty app entitlements file is intentional.
- **Tasks:** Inventory protected capabilities; confirm notifications are local-only; compare Xcode capabilities, source entitlements, profile, and signed entitlements; add nothing without a proven feature requirement.
- **Files:** `DateSnap.entitlements`, `project.yml`, generated project, notification/calendar/reminder/photo services.
- **Dependencies:** Final feature scope and signed archive.
- **Output artifacts:** Capability matrix and entitlement dumps.

### TestFlight QA and release evidence

- **Goal:** Validate the exact uploaded build on physical hardware.
- **Tasks:** Capture automated results; execute fresh-install, permission, OCR, StoreKit, offline, memory, and traffic checks; correct the Photos-denial expectation currently naming `CalendarPermissionDeniedView`; compare production StoreKit products rather than only local configuration; scope “zero network requests” around user links and StoreKit system traffic.
- **Files:** QA runbook, StoreKit config/service, paywalls, tests, and permission flows.
- **Dependencies:** Processed internal TestFlight build.
- **Output artifacts:** Signed QA matrix, device/OS matrix, diagnostics, defect disposition.

### App Review submission readiness

- **Goal:** Submit accurate metadata and a reviewer-ready build.
- **Tasks:** Walk every note against the uploaded build; confirm demo labels/behavior; attach and verify four subscriptions; verify privacy/support/marketing URLs; provide reviewer contact; complete screenshots, age rating, privacy, export, and phased-release fields.
- **Files:** App Review notes, release runbook, StoreKit config/service, paywall views.
- **Dependencies:** TestFlight and compliance signoff.
- **Output artifacts:** Final notes, metadata checklist, IAP attachment proof, URL verification, submission record.

## 6. Task Breakdown

1. **Priority: blocker — Triage the working tree.**
   - **Rationale:** Defines candidate scope.
   - **Files to inspect:** `project.yml`, app icon, `.freebuff/`, `HANDOFF.md`, audit, `lancedb/`.
   - **Files to edit:** None before classification; `.gitignore` only if approved.
   - **Commands or checks to run:** `git status --short --branch`; `git diff --stat`; path-specific diffs; safe inspection of untracked content.
   - **Expected output:** Owner decision for every dirty path; no runtime data staged.
   - **Owner role suggestion:** Release manager + code owner.

2. **Priority: blocker — Resolve Apple team and app registration.**
   - **Rationale:** Placeholder signing blocks distribution.
   - **Files to inspect:** Both xcconfigs, export plist, release runbook.
   - **Files to edit:** Release xcconfig, optionally Debug xcconfig, export plist, release runbook.
   - **Commands or checks to run:** Search `YOUR_TEAM_ID`; verify Certificates, Identifiers & Profiles and App Store Connect.
   - **Expected output:** Approved Team ID and confirmed `com.datesnap.app` registration.
   - **Owner role suggestion:** Apple account holder + release engineer.

3. **Priority: blocker — Establish version/build.**
   - **Rationale:** Upload needs an unused monotonically increasing build.
   - **Files to inspect:** Base xcconfig, Info.plist, App Store Connect history.
   - **Files to edit:** Base xcconfig if `1.0.0 (1)` is not selected/unused.
   - **Commands or checks to run:** Release `-showBuildSettings`; built Info.plist via `plutil -p`.
   - **Expected output:** Approved and resolved version/build.
   - **Owner role suggestion:** Product owner + release manager.

4. **Priority: high — Decide iOS 18-only launch support.**
   - **Rationale:** The configuration is consistent but limits eligible devices.
   - **Files to inspect/edit:** `Package.swift`, `project.yml`, base xcconfig, QA runbook.
   - **Commands or checks to run:** Compare evaluated deployment target; validate APIs before any lowering.
   - **Expected output:** Signed retain/change decision and matching QA/store positioning.
   - **Owner role suggestion:** Product owner + staff iOS engineer.

5. **Priority: high — Regenerate and reconcile the Xcode project.**
   - **Rationale:** Modified YAML controls resource membership.
   - **Files to inspect/edit:** `project.yml`; generated project only through the established generator.
   - **Commands or checks to run:** Determine XcodeGen version/command (**verification required**); regenerate; diff; `xcodebuild -list`.
   - **Expected output:** Project matches YAML and contains app/test scheme plus assets/privacy resources.
   - **Owner role suggestion:** iOS build engineer.

6. **Priority: blocker — Validate effective Release settings.**
   - **Rationale:** Project/target values may override source config.
   - **Files to inspect/edit:** xcconfigs, project.yml, generated project, Info.plist; edit only incorrect sources.
   - **Commands or checks to run:** `xcodebuild -showBuildSettings -project DateSnap.xcodeproj -scheme DateSnap -configuration Release`.
   - **Expected output:** Correct bundle ID, versions, target, plist, entitlements, signing, optimization, testability, validation.
   - **Owner role suggestion:** Release/build engineer.

7. **Priority: high — Reconcile privacy declarations.**
   - **Rationale:** Minimal manifest must describe the whole archive.
   - **Files to inspect/edit:** Privacy manifest, Package.swift, required-reason API uses; edit manifest only from evidence.
   - **Commands or checks to run:** Source scan; Xcode privacy report; embedded-manifest inspection.
   - **Expected output:** API-to-reason mapping and no unexplained warning.
   - **Owner role suggestion:** Privacy engineer + staff iOS engineer.

8. **Priority: high — Verify permission prompts and denied states.**
   - **Rationale:** Purpose strings must match invoked APIs and UX.
   - **Files to inspect/edit:** Info.plist, permission services, HomeViewModel, denied views, QA runbook.
   - **Commands or checks to run:** Fresh-install physical-device tests with permission resets.
   - **Expected output:** Accurate prompts and graceful authorized/limited/denied/restricted flows.
   - **Owner role suggestion:** iOS engineer + QA.

9. **Priority: high — Reconcile capabilities and signed entitlements.**
   - **Rationale:** Checked-in entitlement dictionary is empty.
   - **Files to inspect/edit:** Entitlements, project capabilities, services, profile; edit only for proven requirements.
   - **Commands or checks to run:** `codesign -d --entitlements :- <App.app>` and profile decoding.
   - **Expected output:** Matching capability matrix with no unexplained entitlement.
   - **Owner role suggestion:** iOS platform engineer.

10. **Priority: high — Validate StoreKit production parity.**
    - **Rationale:** Four local products exist, but production state is external.
    - **Files to inspect/edit:** StoreKit config/service, PurchaseViewModel, paywalls, App Review notes.
    - **Commands or checks to run:** Compare IDs, groups, pricing, trials, localization; sandbox purchase/restore/expiry.
    - **Expected output:** Production/local parity and passing entitlement transitions.
    - **Owner role suggestion:** Monetization engineer + App Store Connect owner.

11. **Priority: blocker — Run automated candidate tests.**
    - **Rationale:** No passing result currently supports release.
    - **Files to inspect/edit:** All `Tests/DateSnapTests/`; fix real failures without weakening assertions.
    - **Commands or checks to run:** `xcodebuild test ... -destination 'platform=iOS Simulator,name=<available iOS 18 device>' -resultBundlePath <evidence>/DateSnapTests.xcresult`; run `DATESNAP_EVAL_LIVE=1` where compatible.
    - **Expected output:** Zero unexplained failures, documented skips, retained xcresult.
    - **Owner role suggestion:** iOS engineer + QA automation.

12. **Priority: blocker — Freeze and tag candidate.**
    - **Rationale:** Evidence must map to immutable source.
    - **Files to inspect/edit:** Complete staged diff; no post-freeze edits.
    - **Commands or checks to run:** `git diff --check`; `git status --porcelain`; commit/review; annotated tag and SHA verification.
    - **Expected output:** Clean tree and RC tag at reviewed SHA.
    - **Owner role suggestion:** Release manager.

13. **Priority: blocker — Archive, inspect, validate, and export.**
    - **Rationale:** Produces the submission artifact.
    - **Files to inspect/edit:** Release runbook, export plist, archive metadata; edit only for proven config defects.
    - **Commands or checks to run:** Corrected `xcodebuild clean archive`, `xcodebuild -exportArchive`, `plutil`, `codesign`, and profile inspection.
    - **Expected output:** Valid archive, IPA, dSYM, logs, metadata, privacy manifest, entitlements.
    - **Owner role suggestion:** Release engineer.

14. **Priority: high — Update release and QA runbooks from proven execution.**
    - **Rationale:** Current docs include placeholders, unverified upload tooling, an incorrect Photos-denial target, and absolute network wording.
    - **Files to inspect/edit:** Release and TestFlight QA runbooks.
    - **Commands or checks to run:** Execute every documented command; peer-review QA steps.
    - **Expected output:** Reproducible commands with documented variables and accurate expectations.
    - **Owner role suggestion:** Release manager + QA lead.

15. **Priority: blocker — Upload exact IPA and complete TestFlight QA.**
    - **Rationale:** Real permissions, StoreKit, performance, and hardware behavior require physical-device testing.
    - **Files to inspect/edit:** QA runbook/record; code changes require a new candidate.
    - **Commands or checks to run:** Supported upload workflow; physical-device matrix; Instruments and scoped traffic checks.
    - **Expected output:** Passed checklist, device/build evidence, crash/leak/network record, signoff.
    - **Owner role suggestion:** QA lead + release manager.

16. **Priority: high — Finalize App Review package.**
    - **Rationale:** Claims and URLs are not yet externally verified.
    - **Files to inspect/edit:** App Review notes and release runbook.
    - **Commands or checks to run:** URL checks; reviewer walkthrough; privacy/IAP metadata comparison.
    - **Expected output:** Accurate notes, live URLs, attached IAPs, metadata, reviewer contact.
    - **Owner role suggestion:** App Store Connect owner + product/legal reviewer.

17. **Priority: medium — Add repeatable evidence automation.**
    - **Rationale:** Reduces future release drift.
    - **Files to inspect/edit:** Existing automation (**none verified**); new scripts/CI require separate scope approval.
    - **Commands or checks to run:** Validate from a clean clone.
    - **Expected output:** One workflow captures settings, tests, archive metadata, and checksums without secrets.
    - **Owner role suggestion:** Build/release engineer.

## 7. Dependency Order

1. **Scope gate:** Tasks 1–4 first. Do not lower deployment target, delete untracked content, or commit account configuration without owner decisions.
2. **Configuration:** Tasks 5–6 after Team ID/version decisions.
3. **Parallel pre-freeze work:** Tasks 7–10 can run in parallel after dependency and feature scope stabilize.
4. **Automated quality gate:** Task 11 after config changes settle; fixes invalidate affected results.
5. **Freeze gate:** Task 12 only after pre-freeze blockers/high checks pass.
6. **Distribution gate:** Task 13 from a clean checkout of the tagged SHA. Source fixes require a new build, SHA, evidence set, and tag.
7. **Documentation/TestFlight:** Task 14 may start earlier but finalize from proven commands; then Task 15 on the exported build.
8. **Submission gate:** Task 16 only after QA, privacy, signing, IAP, and URL checks pass.
9. **Optional hardening:** Task 17 may follow release unless adopted as policy.

Gate rules: no tag with dirty state or placeholders; no upload without passing tests/archive/export; no submission without critical physical-device QA and accurate metadata; any post-tag product/config change creates a new candidate.

## 8. Verification Matrix

| Area | Verification step | Evidence required | Pass criteria | Blocking if failed (Yes/No) |
|---|---|---|---|---|
| clean git state | Check candidate checkout/tag | Status, SHA, annotated tag | Empty status; tag resolves to reviewed SHA | Yes |
| resolved version/build numbers | Evaluate settings and built plist | Settings capture and plist dump | Approved unused values agree everywhere | Yes |
| release config correctness | Evaluate Release target | Full build-settings artifact | Correct ID, target, plist, entitlements, optimization, signing | Yes |
| archive success | Archive tagged SHA | Log and archive metadata | Zero exit; app and dSYM present | Yes |
| export success | Export App Store IPA | Log, IPA, checksum | Zero exit; valid IPA | Yes |
| privacy manifest completeness | Compare source/dependencies/report/archive | API/reason inventory and report | All reasons declared; data/tracking claims match | Yes |
| entitlements/capabilities alignment | Compare config/profile/signed app | Matrix and dumps | No missing/unexplained entitlement | Yes |
| permission prompt accuracy | Fresh-install device tests | Screenshots/video and checklist | Correct prompts; limited/denied recovery passes | Yes |
| automated tests | Run full suite/live disposition | xcresult, logs, skip rationale | No unexplained failure | Yes |
| critical-path QA | Execute TestFlight matrix | Signed device/build checklist | All critical/high flows pass | Yes |
| StoreKit production parity | Compare ASC and sandbox test | Metadata proof and result | Four products/trials/lifecycle match | Yes |
| minimum OS decision | Approve strategy | Product/release approval | Store and QA align to effective iOS 18.0 | Yes |
| encryption declaration | Review final binary/dependencies | Compliance record | `false` remains accurate | Yes |
| App Review notes completeness | Walk through uploaded build | Approved final notes | Every claim/action/contact is accurate | Yes |
| external URLs | Open production URLs | Timestamped verification | Privacy/support URLs are live | Yes |
| crash/memory/network evidence | TestFlight/Instruments/scoped observation | Method, duration, reports | Existing QA gate met or formally revised | Yes |
| runbook repeatability | Second operator verifies | Peer-review record | No placeholders; commands reproduce artifact | No |
| release automation | Optional clean-clone run | Workflow log | Evidence reproduced without secrets | No |

## 9. File-Level Change Map

| File path | Why it matters | Likely action | Risk if incorrect |
|---|---|---|---|
| `project.yml` | Target/resource/config authority | Accept resource change; regenerate/review | Manifest/assets missing or project drift |
| `DateSnap.xcodeproj/` | Actual documented build input | Regenerate per convention | Built settings differ from reviewed source |
| `Package.swift` | Platform and package graph | Retain/change iOS 18 only by decision | Project/package mismatch |
| `Config/DateSnap-Base.xcconfig` | ID, version/build, target | Confirm or increment | Rejected/wrong version |
| `Config/DateSnap-Debug.xcconfig` | Developer signing | Replace placeholder if policy requires | Local builds fail |
| `Config/DateSnap-Release.xcconfig` | Distribution behavior/signing | Replace placeholder; validate | Archive/sign failure |
| `Info.plist` | Metadata, prompts, encryption | Edit only for verified mismatch | Runtime crash/review rejection |
| `PrivacyInfo.xcprivacy` | Privacy declarations | Update only from inventory | Validation failure/misrepresentation |
| `DateSnap.entitlements` | Signed capabilities | Keep empty if verified | Missing or excessive privilege |
| `ExportOptions-AppStore.plist` | App Store export/team | Replace placeholder; validate options | Export/wrong-team failure |
| `DateSnap.storekit` | Local subscription model | Reconcile production parity | Local-only success, production failure |
| `Sources/DateSnap/Services/PhotoLibraryService.swift` | Photos/offline behavior | Verify scope and states | Privacy or scan defect |
| `Sources/DateSnap/Services/CalendarService.swift` | Calendar full access | Verify prompt and CRUD | Permission/write failure |
| `Sources/DateSnap/Services/ReminderService.swift` | Reminder full access | Verify prompt/create | Permission/review mismatch |
| `Sources/DateSnap/Services/NotificationService.swift` | Local alerts/deep link | Verify local-only and denial | Broken alerts/capability confusion |
| `Sources/DateSnap/Services/SubscriptionService.swift` | Product IDs/entitlements | Verify lifecycle/parity | Revenue/access defect |
| `Sources/DateSnap/ViewModels/HomeViewModel.swift` | Permission orchestration | Verify transitions/errors | First-run/denial failure |
| `Tests/DateSnapTests/` | Automated evidence | Run all; strengthen proven gaps | Regression or false confidence |
| `docs/runbooks/RELEASE.md` | Operator procedure | Remove placeholders; prove commands | Failed/non-reproducible release |
| `docs/runbooks/TESTFLIGHT-QA.md` | QA gate | Correct denial/network wording; record build | False pass/fail |
| `docs/runbooks/APP-REVIEW-NOTES.md` | Review claims | Verify claims, links, IAPs, contact | Delay/rejection |
| `Assets.xcassets/AppIcon.appiconset/DateSnap-AppIcon-1024.png` | Store asset/dirty item | Review and intentionally commit/revert | Validation/branding defect |
| `.gitignore` | Tree hygiene | Add only approved exclusions | Hidden required input |
| `lancedb/` | Protected runtime data | Do not delete or stage | Data loss/repository bloat |

### Required pre-release fixes

- Resolve signing placeholders; finalize version/build; synchronize YAML/generated project.
- Correct any privacy, permission, entitlement, StoreKit, or reviewer mismatch found by verification.
- Replace runbook placeholders and factual QA errors with proven instructions.

### Verification tasks

- Confirm iOS 18 decision, Apple account/profile state, privacy/encryption declarations, signed capabilities, and production IAP state.
- Run automated tests, archive/export, TestFlight QA, Instruments, scoped network observation, URL validation, and reviewer walkthrough.
- Decide the release-evidence retention location.

### Optional hardening tasks

- Add an evidence template/checksum manifest and clean-clone release automation.
- Add meaningful launch/permission integration or UI tests beyond the trivial smoke test.
- Pin/document XcodeGen and define phased-release rollback triggers for crash, purchase, permission, and event-creation failures.
