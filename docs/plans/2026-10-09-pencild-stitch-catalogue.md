# Pencil'd Stitch Screen Catalogue

**Stitch project:** `9850514973960087780`<br>
**Catalogue purpose:** canonical deduplicated inventory and navigation map for downloading the project assets.<br>
**Sources consolidated:** `docs/audits/stitch-screens.md`, `docs/plans/manifest.md`, `docs/plans/pencild-refresh-audit.md`, and `docs/plans/stitched-screen-mapping.md`.<br>
**Primary hierarchy source:** the former `docs/audits/stitch-screens.md`, consolidated here; the other documents refer to `docs/prompts/stitch-screens.md`, which is not present in this checkout.<br>
**Status note:** This is a synthesis of the four documents, not a fresh query of Stitch. Their “61 screen” claims and IDs are therefore source-reported, not verified against the live project or download status.

## Inventory and counting rules

Use the rows below as records, not as mutually exclusive category totals. Each screen/artifact has one primary category; some records are additionally cross-listed as edge or marketing material. Retain the original Stitch/project ID separately from the reference catalogue ID. The source documents claim 61 project screens, but list only **58 distinct identifiers** across their tables. Of those 58: **36** are unique app screens in the seven product domains; **3** are distinct edge-state screens; **16** are marketing/brand collateral records (one also maps to the reference catalogue); **2** are architecture/meta records; and **1** is the Batch Scan Queue v2 variant (same reference screen as the original queue). This is a deduplicated identifier count, not a verified count of live Stitch objects.

The reference catalogue has **40 records**: 36 primary app screens, 3 edge states, and 1 desktop marketing/copy record. The old audit’s “30 app screens” conflicts with its own category breakdown and mapping tables, which enumerate 36. See [Source conflicts and uncertainties](#source-conflicts-and-uncertainties).

## ID conventions

- **Reference ID**: legacy canonical screen key documented in the screen catalogue. These are usually 32-character lowercase hex strings.
- **Project ID**: identifier listed for the Stitch project record in the mapping/manifest documents. Usually 32-character lowercase hex; five collateral IDs are decimal strings and must be preserved exactly.
- The audit also mentions a separate “Live Canvas Item ID” layer and gives `19890c6eccda4ab4af40606b516bfd42` as an example for Home. No systematic mapping for this third ID layer is included, so do not substitute it for either ID above.

## Primary app-screen inventory

`Parent` is the primary navigation parent recorded in the reference catalogue. Tab roots and root-entry screens are marked explicitly. “Also edge” or “also marketing” denotes a cross-listing, not a second screen.

### 1. Brand & Onboarding / Entry

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| Home Empty State | `e94d669cef5a4ad5bcf0a7ed72e7e938` | `fbe4384a12264d05beabb17d381cb56a` | Root tab | Clean-slate landing, brand/value proposition, “Capture Schedule” CTA and tab bar. CTA → Source Chooser; tabs → Agenda, Automatic Review, Settings. Also cross-listed in marketing inventory. |
| Pencil'd Splash Screen | `e166be75965c43b5b525bbf2a9213a7f` | `83c1bbed375c4e64a11e4d6cf118ddcb` | Application entry; cinematic fullscreen | Glowing crest, wordmark, tagline “Scanned. Reviewed. Pencil'd.” and orbital visuals; launch transition → Home Empty State. |

### 2. Ingestion & Capture Flow

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| Source Chooser / Capture Events | `16ba66e852cf4f05bdfd0def84d89899` | `ff3f9dc009634ef184ee1265fe01bbb8` | Home; stack | Camera, photo library, PDF/file, screenshot/camera-roll triage, manual event creation, and demo-flyer entry. → Scan Processing, PDF & File Review, Screenshot Triage, Edit Event (manual create), Batch Scan Queue. |
| Scan Processing Progress | `a307a3147a1f47d7ab545178a0eabd81` | `7518b065195d472b95d1de6c531f5305` | Source Chooser; stack/modal progress | On-device OCR/entity/date/conflict stages and confidence indicator. → Event Review & Edit for one event, Review Multiple Events for multiple events, or No Dates Found. |
| Batch Scan Queue (original) | `81223b00062b46c0a06a0c79a6b5ad60` | `662f5ef79f254460b641f03be61c00b1` | Source Chooser; stack | Background queue status, thumbnails, success count and batch actions. → Review Multiple Events; inspect an item in Extraction Details. |

### 3. Extraction & Review Pipeline

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| Event Review & Edit (verification) | `ec7fcceed7a24971ae74c7b9d0dbbca7` | `f81f5f07d496494d86fb5b4ddadfa74f` | Scan Processing or Source Chooser; stack | Compare source with parsed title/date/time/location, confidence and conflicts; notes; explicit Save to Calendar. → Edit Event, Reminder Schedule Editor, Saved Event Detail after save, Extraction Details. |
| Review Multiple Events | `b96499d3188a4b52a2cd386e3b4e8f28` | `cff09c75a5644009a91980039885eb50` | PDF & File Review or Batch Scan Queue; stack | Multi-event triage, selection checkboxes, conflict badges and bulk “Pencil In All Selected”. → Event Review & Edit per item; Agenda after bulk save. |
| Automatic Review | `b726b180de014de4a88b13d4f315f7e5` | `83b470e1c9204a508956455573bfd841` | Root tab | Pending items from passive/share/screenshot capture; user confirmation required. → Event Review & Edit or Review Multiple Events. |
| Extraction Details | `f0b02ea3d50e452e91c61fe03ba087ba` | `066c3f7d70c542d5a59daa1f2646e1ee` | Event Review & Edit; stack | Raw OCR blocks, bounding boxes, confidence, timezone and syntax details; returns to Event Review & Edit. |
| PDF & File Review | `9f640bd6ad79459898892de895391544` | `055befddc2214768aca60f2ef44fc33f` | Source Chooser; stack | Multi-page document, thumbnails, extracted-event list and page-range selection. → Review Multiple Events or Event Review & Edit for an individual result. |
| Screenshot Triage | `dfbea9bc83d1466aba5974c253b4db71` | `06b14b0141ea45f6b17c298dbdb72b06` | Source Chooser; stack | Triage event-like images detected in the photo library by Screenshot Radar. → Event Review & Edit or Automatic Capture settings. Also cross-listed by the manifest as marketing/edge material. |

### 4. Calendar & Event Details

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| Agenda | `c9534010e1114ba7bd297edc22f1c9ff` | `f28e0e9083b14d36adb4704f55aee638` | Root tab | Timeline of verified events, date/category filters and Apple Calendar/iCloud sync status. → Event Details; Source Chooser via add/camera action. |
| Event Details | `5b23fc34d25d47949a1229ac42cebfad` | `7407fd1d5a964b55953c301c8e917305` | Agenda; stack | Event schedule, map/location, notes, source flyer and conflict status. → Edit Event or Reminder Schedule Editor. |
| Saved Event Detail | `cf306ab941854322aaf0d07d7c533a91` | `1032e689b29a47939c6c78698052bc04` | Event Review & Edit; stack | Post-save confirmation, event summary, timing rationale and active reminders; share event; → Reminder Schedule Editor or Agenda. |
| Edit Event | `71a8a0266972488d886fc1ccb2aea981` | `9d3fb88befbb41e58764a589104c6176` | Event Details or Event Review & Edit; stack/modal | Title, all-day, start/end, timezone, location, target calendar and notes; returns to caller. |
| Reminder Schedule Editor | `117742cd4c37404ca2238afe1be6a047` | `2be50785f7984d278ea209ebb04586ec` | Event Review, Event Details or Saved Event Detail; stack | Per-event reminder offsets, push/SMS dispatch settings, update phone number and link to global presets. Returns to invoking event screen; → Verify Phone Number or Reminder Presets. |
| History & Archive | `d03171235a96456a9249a4daa03c7624` | `88b16e4687d644a995a3ec0c3cf854ac` | Root management tab or Settings subview | Past scans, flyers and imported files; search, source filters, re-extraction. → Extraction Details. |

### 5. Settings & Functional Sub-Screens

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| Settings | `0f3874c6088b482b872bfd5b5f312eb7` | `190f858174284706925d97c3896183b4` | Root tab | Hub for account, ingestion, notification, calendar, intelligence, subscription and support settings. → Profile, Automatic Capture, Source Preferences, Default Calendar, Notification Preferences, Reminder Presets, Smart Suggestions, Privacy & Processing, Manage Subscription, Help & Support, App Preferences. |
| Automatic Capture | `22898da21df9424ab424cfbfef45fd03` | `48e1e7cc3474407184365c4c4b876a0e` | Settings; stack | Screenshot Radar, photo-library indexing frequency, clipboard detection and battery optimization; → Screenshot Triage. |
| Source Preferences | `7dd0255a932141d79138f3b97a452fc9` | `70672a6c87cb4dfda8c326199980ab26` | Settings; stack | Source priorities, supported parsers (PDF, PNG, Notes, WhatsApp in catalogue copy), OCR image compression. |
| Default Calendar | `f3d0483edc2a43438cfa34e37205fecd` | `51e330d6e9fc4fefb81e140cd7f29838` | Settings; stack | Calendar services, default target/color and write access. Permission failure → Calendar Permission Denied. Also cross-listed in edge/marketing inventory. |
| Notification Preferences | `4f7fb7c09ca442b1935ed0f729924f6b` | `73bc7e2b84d64b6fb5b06b11f16c8821` | Settings; stack | Push, badge, sound, weekly agenda and SMS settings. Permission failure → Notification Permission Denied; SMS setup → Verify Phone Number. |
| Reminder Presets | `e2ef8e9041a74d2fa2dd543b653fa2d3` | `743a9b3e34ca4e198f168ac427bb3dcc` | Settings (and Reminder Schedule Editor); stack | Global default alert intervals for new events. |
| Smart Suggestions | `89f60140b09c4ad78fc9705e9dbbde84` | `7b9ac49f4cb8429f89fcdbe7a385231b` | Settings; stack | Conflict sensitivity, travel-time estimate, duplicate merge and course-code tags. |
| Privacy & Processing | `0af7876285d64dd59f9b6f1a25285fe2` | `386887cd99e644d58df555eb784e03f1` | Settings; stack | On-device Neural Engine, iCloud Keychain sync, cache clearing and Face ID lock controls (as described by the source catalogue; verify claims against live designs before implementation). |
| App Preferences | `5681a6bf69114d778619f925469aa25e` | `c77e5205b8504b858b783cc58241bac7` | Settings; stack | Week start, 12/24-hour format, app icon variant and haptic intensity. |
| Help & Support | `7098b1759cde482ab97dfcbbdeb9ccfc` | `603036ba090a43fa89c09f56742c3c2c` | Settings; stack | FAQ, scan tutorials, diagnostic export, bug report and support contact. |

### 6. Account, Security & Verification Flows

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| User Profile | `80ec0320a47a4f6f9ff8c98bec1e6a5d` | `e1579dc2f4b44b999727d1d14f8aea4a` | Settings; stack | Avatar, Apple ID link, tier, contact channels, scan stats and sign-out. → Verify Phone, Verify Email, Manage Subscription. |
| Verify Phone Number | `1e01d494177a4ab4bff2ef6014d788e4` | `b668f96e38cc4d218448aa79ea087842` | Profile or Reminder Schedule Editor; stack | Country code, formatted number, SMS/WhatsApp dispatch choice and privacy text; Send Code → Enter Phone SMS Code. |
| Enter Phone SMS Code | `b01ff3968f5a41e091549e94981e6563` | `8312446ef9704f9190521c251b4d3edc` | Verify Phone Number; stack | Six-digit code, Messages AutoFill, resend timer and status; success → Verification Complete; edit number → Verify Phone; email fallback → Verify Email Address. |
| Verify Email Address | `10feefa51f1a40699d59b22ebea70b22` | `b64f0f2b53f54ecb94ddd3c19a654485` | User Profile; stack | Email entry, domain suggestions, briefing/receipt toggles and encrypted-sync notice; send link/code → Check Email Inbox. |
| Check Email Inbox | `cf05d2e2cc52430093ad092c8a62d76c` | `cb904a46e71c470e9dd4da1548a47c09` | Verify Email Address; stack | Open Mail, manual six-digit entry, expiry/resend; verified link/code → Verification Complete; change address → Verify Email Address. |
| Verification Complete | `a77a1855fc904c529b04aada1d00c5a7` | `fd8816a0703040a7b4329f1dce6a12fc` | Phone or email code flow; confirmation | Verified-channel summary; routes to Settings/Profile or Agenda; can return to originating verification flow. |

### 7. Monetization & Subscription Paywalls

| Screen | Project ID | Reference ID | Parent / shell | Purpose and outgoing destinations |
|---|---|---|---|---|
| Premium Paywall | `b049d1c4c3e7491f867bc5ebd8224b99` | `eab25e1f62d84bd2beb2c91eda10f328` | Modal from Source Chooser, PDF Review, Profile or Settings | Premium benefits and Annual/Monthly/Lifetime options; purchase/dismissal returns to caller; post-purchase/manage → Manage Subscription. |
| Plus Paywall | `7296411f5d9446e3b334a9ab09abf898` | `8e693fe0c6134c9ebdb8044b362893a5` | Modal/caller-defined | Mid-tier scan volume and custom reminders; compare/upgrade → Premium Paywall; return to Settings. |
| Manage Subscription | `b9eabf1d24fb4c7f9e392cd9d58159e3` | `3ae5f792048947cb95c7834693829a1f` | Profile or Settings; stack | Current plan, renewal, tier switching, receipts and App Store subscription management; → Premium Paywall for upgrade; returns to Profile/Settings. |

## Edge-state screens (cross-cutting; 3 unique records)

| Screen | Project ID | Reference ID | Trigger / parent | Recovery destinations |
|---|---|---|---|---|
| No Dates Found | `9cd18db50bf64b8a80431e483052c853` | `b11a3800c14646748573e492eabbdbd2` | Scan Processing finds no date entities | Capture tips/crop/manual creation; retry via Source Chooser; manual event via Edit Event; retry routes through Scan Processing. |
| Calendar Permission Denied | `8e89625cc96f49c48ebed8bfef75b9b0` | `420f4607817a4ab4bf423275d8d520af` | Calendar access denied/revoked from Default Calendar or review flow | Explain write access, link to iOS Settings; return to Default Calendar or Event Review after access is granted. |
| Notification Permission Denied | `6eb304b327e6400ba203aa40d9798a85` | `6c55f02e2a164cee9d3d1ee03cd6e54a` | Notification authorization denied from Notification Preferences or Reminder Schedule Editor | Explain reminder/alert permission, link to iOS Settings; return to Notification Preferences or Reminder Schedule Editor. |

## Project-only collateral and meta records

These identifiers are listed by the old project manifest/mapping but have no canonical app-screen ID unless noted. They must still be fetched if the live project confirms they exist. The source calls the marketing collection “23 screens”; after removing repeated/cross-listed IDs, this section has 16 unique collateral identifiers.

| Project ID | Listed title / type | Catalogue relation / notes |
|---|---|---|
| `c260982726f743cd973a064579946822` | App Store screenshot promo, iPhone 6.9-inch | Marketing-only. |
| `5d72d1bfbe5445ddbd33416047296fce` | App Store screenshot promo, iPad Pro 13-inch | The source table gives `5d72d1bfbe5445ddbd33416047296fce` in both mapping and manifest; this is 32 characters. Preserve this source value. |
| `f34bff7100624055a748acfa6120bf00` | App Store screenshot promo, iPad Pro 13-inch | Marketing-only. |
| `3702545456768888067` | `pencild-splash-bg.png` | Decimal identifier; splash background. |
| `a8d2a1e82bfb4dd3834278ae259c8b08` | App Store screenshot promo, iPhone 6.9-inch | Marketing-only. |
| `a105af88940f4be898ef475ce2735202` | App Store screenshot promo, iPad Pro 13-inch | Marketing-only. |
| `9a80e3a825074d8d969672ee54302157` | App Store screenshot promo, iPhone 6.9-inch | Marketing-only. |
| `5d702c95d77145e183ca08b60cfcb2cd` | App Store screenshot promo, iPhone 6.9-inch | Marketing-only. |
| `11975388127119735582` | `pencild-logo-grey.png` | Decimal identifier; wordmark. |
| `2828115625404236044` | `Marketing Kit.md` | Decimal identifier; marketing documentation. |
| `65a70a58868f45a6b2af0f64ff6ebc54` | Digital banner ad, 16:9 | Marketing-only; described as midnight navy with orange/violet rays. |
| `a71e5d0aabda40b2ac31b4b9d953dc1e` | Marketing Copy & Email Template | Maps to reference catalogue desktop collateral ID `b8f7125d147144598bd55ab3e51620b4`. |
| `8019306492019719328` | `Pencil_tip_app_icon_design_2K_20261007190041.jpg` | Decimal identifier; app-icon design source. |
| `051be17bb3994b2f9b4a5cbf02b6f4f9` | App Store screenshot promo, iPhone 6.9-inch | Marketing-only. |
| `8019306492019717442` | `pencil'd-full-logo-wordmark.png` | Decimal identifier; full wordmark. |
| `ec6850f39a674f65951ab4313389a227` | Email newsletter header banner, 16:9 | Marketing-only. |
| `06c2df8676394c1eb9c6377c56a6e302` | Pencil'd — Screen Catalog & Architecture Map | Meta/architecture item; not an app screen. |
| `b1c4833006a843dcbb7020fdfa831ab9` | Pencil'd — Screen Catalog & Architecture Map | Second meta/architecture item; not an app screen. |
| `fa88dc61326541fa9796e1dff8692b94` | Batch Scan Queue (v2) | Separate project ID, same canonical ID as Batch Scan Queue; decide which visual variant is current after retrieving both. |

**Cross-listed project IDs, do not add as duplicate screens:** Home Empty State `e94d669cef5a4ad5bcf0a7ed72e7e938`; Screenshot Triage `dfbea9bc83d1466aba5974c253b4db71`; Default Calendar `f3d0483edc2a43438cfa34e37205fecd`; No Dates Found `9cd18db50bf64b8a80431e483052c853`; Calendar Permission Denied `8e89625cc96f49c48ebed8bfef75b9b0`; Notification Permission Denied `6eb304b327e6400ba203aa40d9798a85`. The old manifest repeats Notification Permission Denied twice in its marketing list; this catalogue records it once.

> **Count caveat:** The table above lists 16 standalone collateral identifiers plus 2 meta records and the queue v2 variant, separate from the 36 app screens and 3 edge screens. Cross-listed records are counted only once; the sources’ claim of 61 total remains unresolved.

## Navigation relationship index

The primary-parent and outgoing routes appear in the inventory tables. This index states the cross-domain hierarchy in one place; arrows mean “navigates to,” not containment.

- **Entry/tabs:** Splash → Home. Home → Source Chooser; bottom tabs → Agenda, Automatic Review, Settings. History & Archive is described inconsistently as either a root management tab or Settings subview.
- **Ingestion:** Source Chooser → Scan Processing / PDF & File Review / Screenshot Triage / Edit Event (manual create) / Batch Scan Queue. Scan Processing → Event Review & Edit / Review Multiple Events / No Dates Found. Batch Scan Queue → Review Multiple Events / Extraction Details. PDF & File Review → Review Multiple Events / Event Review & Edit. Screenshot Triage → Event Review & Edit / Automatic Capture.
- **Review/save:** Automatic Review → Event Review & Edit / Review Multiple Events. Event Review & Edit → Edit Event / Reminder Schedule Editor / Extraction Details; explicit save → Saved Event Detail. Review Multiple Events → Event Review & Edit; bulk save → Agenda. Saved Event Detail → Reminder Schedule Editor / Agenda.
- **Calendar:** Agenda → Event Details / Source Chooser. Event Details → Edit Event / Reminder Schedule Editor. History & Archive → Extraction Details.
- **Settings:** Settings → Profile / Automatic Capture / Source Preferences / Default Calendar / Notification Preferences / Reminder Presets / Smart Suggestions / Privacy & Processing / Manage Subscription / Help & Support / App Preferences. Default Calendar → Calendar Permission Denied. Notification Preferences → Notification Permission Denied / Verify Phone. Automatic Capture → Screenshot Triage. Reminder Schedule Editor → Verify Phone / Reminder Presets.
- **Verification:** Profile → Verify Phone / Verify Email / Manage Subscription. Verify Phone → SMS Code → Verification Complete; SMS Code can switch to Verify Email. Verify Email → Check Email Inbox → Verification Complete. Verification Complete → Settings/Profile or Agenda.
- **Subscriptions:** Premium Paywall → Manage Subscription or returns to its caller. Plus Paywall → Premium Paywall or Settings. Manage Subscription → Premium Paywall or returns to Profile/Settings.

The source catalogue contains duplicate destinations and multiple opaque references such as `{{DATA:SCREEN:SCREEN_72}}`, `SCREEN_85`, `SCREEN_83`, `SCREEN_64`, etc. These conflict with the named canonical IDs. Resolve them against live Stitch metadata; this catalogue uses the named destination IDs and retains the opaque-reference discrepancy below.

## Design notes recorded by the source documents

- The reference catalogue describes shells/archetypes (tab root, stack, modal/progress, cinematic fullscreen), and the project manifest says the downloaded JSON contains `name`, `title`, `screenshot`, and `htmlCode` but no category. These are claims in the source documents, not verified against the absent current project download.
- One project-manifest marketing description repeatedly calls out dark midnight/navy backgrounds (including `#101127`) with orange/gold/violet/coral glows. This is not a token specification and must not be treated as a canonical shared palette without fetching and inspecting current designs.
- The project’s old screen JSON is described as embedding HTML code and screenshots. The old audit says no separate category field and recommends extracting tokens from the screens. There are **no token values, typography scales, spacing/radius/shadow/icon token files, or per-screen asset paths in these four source documents**.
- The source documents list `docs/prompts/stitch-screens.md` as the screen-hierarchy reference, but that file is absent in this checkout. The full descriptions and relations consolidated into this catalogue from the former `docs/audits/stitch-screens.md` are therefore the available written hierarchy from the four inputs.
- Expected download organization for the next step: one category folder per primary category, parent screens in their own folders, sub-screens nested beneath their parent, and shared tokens in `.stitch/tokens/`. The source documents do not supply an authoritative manifest with fetch status or local paths.

## Source conflicts and uncertainties

1. **Project totals disagree.** The audit claims 61 total, 30 app, 3 edge, 23 marketing, 2 meta. Those components sum to 58 before considering queue v2. The category rows in the manifest sum to 65, while its detailed table has repeated IDs and cross-listed screens. There are 58 distinct identifiers in the listed tables; it is not established whether three project screens are omitted or the 61 claim is wrong.
2. **App count disagrees.** The seven primary category listings enumerate 36 unique app screens (2 + 3 + 6 + 6 + 10 + 6 + 3), not the audit’s 30. All 36 are retained here pending live-project verification.
3. **Marketing count mixes assets and cross-listings.** The manifest labels 23 entries as marketing, but includes app/edge screens and duplicates Notification Permission Denied. The mapping document lists 16 standalone collateral IDs and only a subset of marketing entries. This catalogue deduplicates by identifier and lists cross-listed screens separately.
4. **Canonical “one-to-one” claim is too broad.** The documents claim a direct 1:1 mapping for 30 app screens; the 36 rows actually enumerated in primary product categories appear mapped. Do not infer that all live Stitch records have been reconciled until fetched.
5. **Project identifiers vary in format.** Five collateral IDs in the source tables are decimal strings rather than 32-character hexadecimal values; preserve them verbatim and verify them against Stitch. The iPad promo ID `5d72d1bfbe5445ddbd33416047296fce` is listed consistently in both the mapping and manifest and is 32 characters.
6. **Live Canvas IDs are incomplete.** Only an example is supplied; there is no crosswalk table to the project IDs or reference IDs.
7. **Hierarchy metadata has duplicate/opaque links.** Several edges are duplicated, two destinations use unresolved `{{DATA:SCREEN:...}}` placeholders, and History & Archive has two possible parents. The named direct relations are preserved; validate all against the project.
8. **The described local manifest/assets are not present in the source set.** The old manifest contains screen IDs/titles and status labels, but no per-record category, parent, file paths or fetch status. No actual token catalog is present. Fetch status must be established by the next Stitch download step.
9. **The expected reference file is missing.** `docs/prompts/stitch-screens.md` is named as an authority in the source documents but is not in the current repository. It is not among the four consolidation inputs and is not synthesized as though it were present.

## Input document disposition

This catalogue consolidates the unique inventory, mappings, category/archetype labels, descriptions, hierarchy, ID notes, cross-listings, and design/token observations from the four inputs. Repeated ID tables and repeated prose have been reduced to the normalized tables above; conflicts were retained as explicit issues rather than silently resolved. After review, the superseded files are:

- `docs/audits/stitch-screens.md`
- `docs/plans/manifest.md`
- `docs/plans/pencild-refresh-audit.md`
- `docs/plans/stitched-screen-mapping.md`
