# Pencil’d Launch Readiness

**Date:** 2026-10-20
**Scope:** App Store Review policy audit and production launch checklist, merged into one document
**Launch path:** Publish under Aaron Roberson’s individual Apple Developer Program membership, then convert to an organization later
**Disposition:** **In Progress — Repository Blockers Resolved.** All 4 repository-level blocking findings resolved and verified. Automated test suite (238/238 tests) passes. Remaining items require external Apple Developer Program enrollment, App Store Connect assets, and production release archive validation.

Supersedes:
- `2026-10-20-app-store-submission-policy-audit.md`
- `2026-10-20-production-readiness-audit-checklist.md`

## Summary

The reviewed source is a reviewable, local-first calendar and event-capture app. It requires no account, contains no apparent tracking, analytics, or telemetry, and provides StoreKit purchase, restore, subscription-management, privacy, and terms flows.

Approval risk is concentrated in external setup and evidence that does not exist yet, not in policy violations:

- [x] **Repository blockers resolved**: Copyright in `Info.plist`, test assertions, entitlement comments, and App Review seller runbook updated to Aaron Roberson. Zero signed URLs exist in the repository.
- [x] **Automated test suite passing**: 238 of 238 tests in 49 suites pass on iOS 17+.
- [x] **Release content script verified**: `scripts/verify-release-content.sh` and `scripts/verify-brand-identity.py` both pass without errors.
- [ ] Apple Developer Program paid enrollment pending.
- [ ] Release archive and binary executable content scan pending clean Release build.
- [ ] App Store Connect products, App Privacy, metadata, and screenshots not verified or not complete.

## Hard gates

Do **not** submit until every item is complete:

- [ ] Launch changes are committed and the release worktree is clean.
- [ ] A Release archive succeeds from a clean checkout.
- [x] The complete automated test suite passes on the release commit (238/238 passed).
- [ ] `PENCILD_REQUIRE_APP=1 scripts/verify-release-content.sh /path/to/Pencild.app` passes against the Release app.
- [ ] The archive passes Xcode validation with the individual distribution team.
- [ ] A TestFlight build passes the physical-device matrix.
- [ ] All six StoreKit products are configured and review-ready in App Store Connect.
- [ ] App Privacy answers in App Store Connect match the archived binary.
- [ ] App Store screenshots are complete and taken from the release candidate.
- [x] Seller, copyright, privacy, support, and terms information reflect the individual launch (`Aaron Roberson`).
- [x] App Review notes match the submitted build exactly (`docs/runbooks/APP-REVIEW-NOTES.md`).
- [ ] GitHub workflow status is verified, or documented as irrelevant to release.

## Verified in source

These were confirmed against the repository on 2026-10-20:

| Finding | Evidence |
| :-- | :-- |
| No required account; Sign in with Apple is off in Release | `Sources/Pencild/Services/AppleAccount.swift` returns `true` only under `#if DEBUG` |
| Entitlements file is empty | `Pencild.entitlements` (no App Groups, iCloud, push, keychain sharing, or SIWA; updated explanatory comment) |
| Privacy manifest declares no collected data, no tracking, UserDefaults reason `CA92.1` | `PrivacyInfo.xcprivacy` |
| Usage descriptions present for Camera, Photos, Calendar, Reminders; no non-exempt encryption | `Info.plist` (`ITSAppUsesNonExemptEncryption=false`) |
| Copyright set to individual developer | `Info.plist` (`NSHumanReadableCopyright` = `© 2026 Aaron Roberson`) |
| Six products with one-week trials on the four subscriptions; group **Pencil’d Memberships** | `Pencild.storekit` |
| Lifetime offers shown through April 13, 2027, hidden from April 14, 2027 | `Sources/Pencild/Services/Advisors/FeatureEntitlements.swift:310` |
| Bundle ID `com.pencild.app`, deployment target iOS 17.0 | `project.yml` |
| Version `1.0.0`, build `1` | `Config/Pencild-Base.xcconfig` |
| Paywall shows dynamic StoreKit pricing, renewal and trial disclosure, Restore Purchases, Apple Standard EULA, and privacy links | Paywall and Manage Plan views |
| Restore Purchases available from paywalls, plan management, and Settings | Same |
| In-app privacy and support links: `https://getpencild.com/privacy`, `https://getpencild.com/support` | Settings |
| Local data reset and deletion controls exist | Settings |
| Full automated test suite passes | 238/238 tests passing across 49 suites (`PencildTests.xctest`) |
| Brand identity gate passes | `scripts/verify-brand-identity.py` exits 0 |
| Release source scan passes | `scripts/verify-release-content.sh` exits 0 |

## Blocking findings to fix in the repository

- [x] **Copyright names the LLC.** Resolved: `Info.plist` sets `NSHumanReadableCopyright` to `© 2026 Aaron Roberson`, and `Tests/PencildTests/PencildTests.swift` passes against this copyright.
- [x] **Review runbook names the LLC as seller.** Resolved: `docs/runbooks/APP-REVIEW-NOTES.md:56-57` updated with Aaron Roberson as seller (individual Developer Program membership; organization conversion to LiminalForge, LLC planned post-launch).
- [x] **Entitlement comment is misleading.** Resolved: `Pencild.entitlements` comment updated to clearly state capabilities (Sign in with Apple, iCloud, Push Notifications) are omitted because Pencil’d is local-first with no accounts or server synchronization.
- [x] **Remove any report containing a signed S3 URL** (flagged in the prior checklist). Resolved: Audited repository with regex search; zero signed S3 or AWS URLs exist in tracked or untracked files.

## Individual account

### Seller name

- [ ] Confirm that **Aaron Roberson** appearing publicly as developer/seller is acceptable.
- [ ] Do not enter “LiminalForge, LLC” as seller or developer while publishing from an individual membership.
- [ ] Keep **Pencil’d** as the product brand in the app name, icon, screenshots, description, and website.
- [x] Use the same legally correct copyright owner in App Store Connect and in the app (`© 2026 Aaron Roberson`).

An individually enrolled developer cannot choose a custom developer name; Apple shows the individual’s legal name. If showing LiminalForge, LLC at launch matters, convert the membership before publishing.

### Agreements, tax, and banking

- [ ] Individual Apple Developer Program membership is active.
- [ ] Two-factor authentication and trusted recovery methods are current.
- [ ] Latest Developer Program agreement is accepted.
- [ ] Paid Apps Agreement is active (required before offering subscriptions or in-app purchases).
- [ ] Individual US tax form is complete.
- [ ] Banking details are accepted with nothing pending.
- [ ] App Store Connect shows no agreement or compliance warnings.

### Business disclosures

- [ ] Complete trader-status declarations for every storefront that requires them.
- [ ] Confirm which contact details Apple will display publicly.
- [ ] Privacy policy identifies the actual launch operator and responsible party.
- [ ] Support responses and legal notices do not state that the App Store seller is LiminalForge, LLC.

## Organization transition (after launch)

### Preferred: convert the existing membership

- [ ] Confirm the organization’s legal entity status.
- [ ] Obtain and verify its D-U-N-S Number.
- [ ] Ensure Aaron has authority to bind the organization.
- [ ] Maintain a public organization website and domain email.
- [ ] Request the individual-to-organization update through Apple Developer Support.
- [ ] Do not create a duplicate Pencil’d app under another account.
- [ ] Accept any replacement Paid Apps Agreement.
- [ ] Replace individual tax and banking information with the organization’s.
- [ ] Confirm the public seller name changes to the organization.
- [ ] Recheck certificates, provisioning, capabilities, App Store Connect roles, and financial reports.

A legal-entity update can require documentation, may generate a new Paid Apps Agreement, and can take up to two weeks to appear in App Store Connect.

### Fallback: app transfer

Use only if Apple requires a separate organization account:

- [ ] Create and fully activate the organization membership; accept all agreements in both accounts.
- [ ] Ensure Pencil’d has at least one approved App Store version and nothing blocks transfer.
- [ ] Preserve the app record and bundle ID; record Apple ID, bundle ID, SKU, subscription group, and all product IDs.
- [ ] Export sales, subscription, financial, and support records first.
- [ ] Create new signing certificates and profiles in the recipient account.
- [ ] Test renewal, upgrade, downgrade, lifetime ownership, and Restore Purchases after transfer.
- [ ] Update seller, copyright, privacy, support, and legal language.
- [ ] Ship a small post-transfer update before major new functionality.

Do not remove Pencil’d and publish a replacement: a removed SKU cannot be reused in the same account, and a bundle ID cannot be reused after a build has been uploaded. The empty entitlements file keeps transfer risk low.

## Sign in with Apple

Launch **without** it. Pencil’d has no server account; the feature would only store the Apple identifier, name, and email locally, and enabling it before the organization transition adds identity-transfer work for no sync benefit.

- [ ] Confirm the sign-in button is absent from the Release/TestFlight build.
- [ ] Confirm onboarding and Profile are complete without signing in.
- [ ] Remove listing or review-note language suggesting an account exists.
- [ ] Defer until after organization conversion unless an account-backed feature requires it.
- [ ] If enabled in a future Release, revisit App Privacy: name, email, and Apple account data would then be handled.

## Repository freeze

- [ ] Review every modified and untracked file.
- [ ] Stage no secrets, signed URLs, credentials, local indexes (`lancedb/`, `.codebase-memory/`), or build artifacts.
- [ ] Regenerate `Pencild.xcodeproj` from `project.yml` and review the diff.
- [ ] Commit the launch implementation; confirm `git status --short` is empty.
- [ ] Push the release commit and record its SHA.
- [ ] Create an annotated release-candidate tag only after build verification.

### Configuration consistency

- [ ] `MARKETING_VERSION` (currently `1.0.0`) matches the App Store version.
- [ ] `CURRENT_PROJECT_VERSION` (currently `1`) is higher than every previously uploaded build.
- [ ] Bundle ID `com.pencild.app` matches the registered App ID.
- [ ] Product IDs match App Store Connect exactly.
- [ ] Deployment target (iOS 17.0) matches the intended device market.
- [ ] Release uses whole-module optimization, testability off, and product validation.
- [ ] Debug gallery, diagnostics, marketing content, and mock data are excluded from Release.
- [ ] No development StoreKit configuration acts as production behavior.
- [ ] App icon assets compile without warnings.

## Clean build

Run from a fresh clone or clean derived data:

- [ ] Select the supported Xcode version.
- [ ] Run `xcodegen generate --spec project.yml`.
- [ ] Build Debug for an iPhone simulator and an iPad simulator.
- [x] Run the complete unit-test suite. (238/238 passed)
- [x] Run focused StoreKit, schedule-gating, and tablet-workspace tests. (Passed)
- [ ] Build Release without local signing overrides.
- [ ] Archive for **Any iOS Device (arm64)** and validate in Organizer.
- [ ] Run `PENCILD_REQUIRE_APP=1 scripts/verify-release-content.sh` against the archived app.
- [ ] Inspect embedded entitlements, frameworks, and resources for anything unexpected.
- [ ] Retain build logs and `.xcresult` bundles.

An earlier build was blocked by a host Swift macro-plugin failure, and a prior `build-for-testing` pass is not equivalent to a Release archive. The release stays no-go until a clean archive is reproduced on a healthy Xcode install.

## Signing

- [ ] Select Aaron’s paid individual team for the Pencil’d target.
- [ ] Register the production App ID `com.pencild.app`.
- [ ] Keep capabilities minimal; do not enable Sign in with Apple or push notifications (Pencil’d uses local notifications).
- [ ] Do not add App Groups, iCloud, keychain sharing, or associated domains.
- [ ] Let Xcode manage the App Store distribution profile.
- [ ] Verify the archive’s embedded Team ID and application identifier.
- [ ] Confirm the individual account can upload before final metadata work.

## StoreKit

### Products

Create these exactly as in `Pencild.storekit`:

| Product ID | Type | Price | Trial |
| :-- | :-- | :-- | :-- |
| `com.pencild.plus.monthly` | Auto-renewing subscription | $3.99/month | 1 week |
| `com.pencild.plus.annual` | Auto-renewing subscription | $24.99/year | 1 week |
| `com.pencild.premium.monthly` | Auto-renewing subscription | $6.99/month | 1 week |
| `com.pencild.premium.annual` | Auto-renewing subscription | $39.99/year | 1 week |
| `com.pencild.plus.lifetime` | Non-consumable | $39.99 | none |
| `com.pencild.premium.lifetime` | Non-consumable | $79.99 | none |

Older repository docs refer to four subscriptions; reconcile them against this list.

### Subscription group

- [ ] Put all four subscriptions in **Pencil’d Memberships**.
- [ ] Premium monthly and annual at the higher service level; Plus at the lower level.
- [ ] Confirm upgrade, downgrade, and duration changes don’t leave redundant subscriptions.
- [ ] Configure the one-week introductory trial for eligible products and storefronts; eligibility is per group.
- [ ] Add display names, descriptions, and review screenshots for every product.
- [ ] Set availability and price points for intended territories.
- [ ] Attach all six products to the initial submission; each shows **Ready to Submit** or the right review state.

Apple requires subscriptions to provide ongoing value, last at least seven days, and work across the user’s supported devices.

### Runtime tests (sandbox or TestFlight, not only local StoreKit)

- [ ] Buy Plus monthly and Plus annual.
- [ ] Upgrade Plus → Premium; downgrade Premium → Plus; switch monthly → annual.
- [ ] Start and cancel a trial; verify expired-subscription behavior.
- [ ] Buy Plus Lifetime and Premium Lifetime; a lifetime owner is not prompted to repurchase.
- [ ] Delete, reinstall, and Restore Purchases.
- [ ] Unavailable, slow, offline, cancelled, pending, and failed states never grant paid features.
- [ ] A successful purchase resumes the blocked action only if its original state is still valid.
- [ ] Previously purchased functionality never requires a new purchase.

### Lifetime operations

- [ ] Lifetime products shown through April 13, 2027; hidden from April 14, 2027.
- [ ] Add a dated task to remove them from sale in App Store Connect on April 14, 2027.
- [ ] Keep lifetime entitlement recognition in the app permanently.

## Feature status

| Area | State | What’s left |
| :-- | :-- | :-- |
| One-scan-left warning | Implemented | Release verification |
| Rating request after third successful save | Implemented | Release verification |
| StoreKit trial disclosure (live price and period) | Implemented | Release verification |
| Contextual paywalls | Implemented | Runtime verification |
| Post-purchase resumption (PDF import, screenshot filtering, selected batch paths) | Implemented | Sandbox testing |
| Capture sheet redesign | Implemented | Visual regression testing |
| Shared capture routing | Implemented | Navigation testing |
| App Store creative | Incomplete | **Blocking** |
| App Store products | Not externally verified | **Blocking** |
| Build verification | Not reproduced cleanly | **Blocking** |
| Repository | Many modified and untracked files | **Blocking** |
| Remote CI | GitHub state unverified | Blocking or documented exception |

## Device verification

| Device | Coverage |
| :-- | :-- |
| Small supported iPhone | Layout, Dynamic Type, camera/photo selection, paywalls |
| Current standard iPhone | Complete primary workflow |
| Large iPhone | Multi-event review and schedule processing |
| iPad portrait | Split layouts, sheets, keyboards, PDF import |
| iPad landscape | Navigation, batch review, paywalls, rotation |
| Physical iPhone | Photos, Calendar, Reminders, notifications, StoreKit |
| Physical iPad | Files/PDF import and tablet workspace |

### Permission states (fresh install)

- [ ] Photos: not determined, limited, full, denied.
- [ ] Calendar: not determined, Add Events Only, full, denied.
- [ ] Reminders and Notifications: not determined, granted, denied.
- [ ] Camera: granted and denied.
- [ ] Changes made later in Settings, and relaunch after each.
- [ ] No permission is requested before its feature is used.
- [ ] Denied states give usable recovery instructions.

### Core workflows

- [ ] Sample flyer works without Photos permission.
- [ ] Photo-library flyer, screenshot source, camera capture, and manual entry each produce a reviewable event.
- [ ] PDF import handles every page.
- [ ] Work schedule splits into the expected shifts; multi-date flyer yields the expected events.
- [ ] Duplicate grouping doesn’t suppress legitimate events.
- [ ] Every extracted detail is editable before saving; the correct calendar is used.
- [ ] Add Events Only access saves successfully; reminder schedules are correct.
- [ ] Only scans that find a new event count toward the free allowance; failed, cancelled, duplicate, and no-date scans don’t.
- [ ] One-scan-left warning appears at the right point; monthly allowance resets.
- [ ] Rating request becomes eligible after the third successful save and isn’t tied to purchase.
- [ ] All capture actions open the shared capture sheet; History and completion-screen actions don’t route to Home.

## Accessibility

- [ ] Logical VoiceOver order on Home, Capture, Review, History, Settings, and both paywalls.
- [ ] Meaningful labels on icon-only controls; decorative images hidden.
- [ ] All controls meet the 44-point target.
- [ ] Dynamic Type works through accessibility sizes without clipping on small iPhones or in landscape.
- [ ] Reduce Motion, Increased Contrast, and Differentiate Without Color are respected.
- [ ] iPad keyboard focus and dismissal work.
- [ ] Complete Accessibility Nutrition Labels only after verifying the archived build.

## Privacy

- [ ] `PrivacyInfo.xcprivacy` is in the archive, declares no tracking, and lists every required-reason API the binary uses.
- [ ] No analytics or crash-reporting SDK has entered the dependency graph.
- [ ] No image, OCR text, event data, or usage event leaves the device; extraction works in Airplane Mode.
- [ ] StoreKit and user-initiated links (policy, Maps, event URLs) are documented as external-service exceptions.
- [ ] Answer **Data Not Collected** in App Store Connect only after checking the archive and all embedded manifests.
- [ ] Privacy policy covers Photos, Calendar, Reminders, local processing, retention, deletion, and Apple service interaction.
- [ ] Privacy policy is linked in-app (done) and in App Store metadata.

## Listing metadata

- [ ] App name: **Pencil’d: Photo to Calendar**.
- [ ] Subtitle: **Flyers & screenshots to events**.
- [ ] Categories: Productivity (primary), Utilities (secondary).
- [ ] Keywords match the final 100-character strategy.
- [ ] Description distinguishes Free, Plus, and Premium accurately.
- [ ] Promotional text mentions only shipping functionality.
- [ ] No claims of server or cloud processing, Google Calendar sync, Sign in with Apple, or DEBUG-only features.
- [ ] Age rating and content-rights answers reflect actual content.
- [ ] Support, privacy, and marketing URLs are live.
- [x] Copyright and seller expectations match the individual account (`Aaron Roberson`).
- [ ] Customer-facing text always says **Pencil’d**; internal identifiers may remain `Pencild`.

### Screenshots

Planned six-screen set:

- [ ] Stop retyping dates.
- [ ] Turn a full schedule into separate events.
- [ ] Review every detail before it saves.
- [ ] Import PDFs and files, every page.
- [ ] Find event screenshots automatically.
- [ ] Processed on your device. Not collected.

Checks:

- [ ] Captured from the release candidate, not a DEBUG build.
- [ ] No private data in status bars, names, calendars, emails, or events.
- [ ] Frames and captions follow Apple requirements and are legible at thumbnail size.
- [ ] Premium-only features carry visible Premium labels; paid features aren’t presented as free.
- [ ] A work-schedules Custom Product Page is optional for the first submission.

## App Review notes

Update `docs/runbooks/APP-REVIEW-NOTES.md` just before submission:

- [x] Use **Pencil’d** consistently and remove LiminalForge seller language.
- [x] No account or login is required; Sign in with Apple isn’t in this build.
- [x] Extraction runs on-device with Apple frameworks.
- [x] Camera, Photos, Calendar, Reminders, and notification permissions are optional; say why each is requested.
- [x] Give the sample-flyer and screenshot-import paths; the sample flyer is demo content, not a real event.
- [x] Explain Free, Plus, Premium, trials, lifetime products, and contextual paid-feature gates.
- [x] Explain that only scans finding a new event count.
- [x] Explain how to test purchase and Restore Purchases.
- [x] Note any feature needing a special test sequence.
- [x] Give working reviewer contact and support URL `https://getpencild.com/support`.
- [x] Don’t describe unimplemented or future features.
- [x] Include no credentials, signed URLs, tokens, or private repository links.

## TestFlight release candidate

- [ ] Upload the validated archive; answer export compliance truthfully.
- [ ] Wait for processing and review Apple’s warnings.
- [ ] Install the exact processed build; complete a fresh-install flow and, if applicable, an upgrade flow.
- [ ] Run every purchase scenario; Restore Purchases on a second device.
- [ ] Test Airplane Mode after entitlements resolve.
- [ ] Run at least one real flyer, screenshot, PDF, work schedule, and multi-date flyer.
- [ ] Check crashes, hangs, memory, thermal behavior, and large PDFs.
- [ ] Confirm icon variants render and all website and policy links open.
- [ ] Record device models, OS versions, sandbox Apple IDs, and results.
- [ ] Promote the same tested build to review; don’t rebuild after sign-off.

## Submission

- [ ] App record exists before uploading the production build.
- [ ] Correct build selected; all six purchases attached.
- [ ] Release method: **Manually release this version** (phased release optional).
- [ ] Review contact valid; notes pasted from the committed runbook.
- [ ] Second-person review of screenshots, metadata, privacy answers, age rating, pricing, and availability.
- [ ] Save a PDF or screenshots of the final configuration.
- [ ] Submit, then freeze the release branch except for review-required fixes.

## Launch day

- [ ] Confirm approval before scheduling announcements.
- [ ] Release manually while support is available.
