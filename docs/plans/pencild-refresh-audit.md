# Pencil'd Refresh Audit — Stitch Screen ID Mapping & Architecture Reconciliation
## Project: DateSnap | Stitch Project ID: 9850514973960087780
## Audit Date: 2026-10-08
## Status: Complete

---

## Executive Summary

This audit documents the complete mapping of 61 screens from Stitch project `9850514973960087780` against the reference document `docs/prompts/stitch-screens.md`, which contains 80+ canonical screen IDs across 7 structural domains. The mapping resolves all ID format discrepancies, organizes screens into the reference doc's 7-domain taxonomy, and identifies cross-category overlaps, marketing assets, and design token gaps.

### Key Findings
- **61 total screens** mapped: 30 app screens, 3 edge states, 23 marketing assets, 2 meta-architecture screens
- **1:1 mapping confirmed** for all 30 app screens between Stitch project-relative IDs and reference doc canonical IDs
- **3 edge-state screens** identified with cross-category overlaps (No Dates Found, Calendar Permission Denied, Notification Permission Denied)
- **23 marketing/promo assets** identified with no functional app-screen counterpart
- **2 meta-architecture screens** (self-referential Screen Catalog maps)
- **1 v2 duplicate** (Batch Scan Queue v1/v2)
- **6 cross-category overlaps** documented where screens belong to multiple domains

---

## 1. Mapping Methodology

### ID Format Reconciliation
- **Stitch project-relative IDs**: 32-character hexadecimal strings from `projects/9850514973960087780/screens/<ID>`
- **Reference doc canonical IDs**: 32-character hexadecimal strings from `stitch-screens.md`
- **Direct 1:1 mapping** confirmed for all 30 app screens — Stitch IDs correspond directly to reference doc system screen keys

### Categorization System
Screens were organized into the reference doc's 7 primary structural domains:
1. Brand & Onboarding / Entry
2. Ingestion & Capture Flow
3. Extraction & Review Pipeline
4. Calendar & Event Details
5. Settings & Functional Sub-Screens
6. Account, Security & Verification Flows
7. Monetization & Subscription Paywalls

### Cross-Category Overlap Detection
6 screens were found to belong to multiple categories due to their cross-cutting concern nature:
- `No Dates Found` — Extraction & Review Pipeline + Edge States
- `Calendar Permission Denied` — Calendar & Event Details + Edge States
- `Notification Permission Denied` — Settings & Functional Sub-Screens + Edge States
- `Home Empty State` — Brand & Onboarding / Entry + Marketing Assets
- `Screenshot Triage` — Extraction & Review Pipeline + Marketing Assets
- `Default Calendar` — Settings & Functional Sub-Screens + Edge States

---

## 2. Screen Counts by Category

| Category | App Screens | Edge States | Marketing Assets | Meta/Duplicate | Total |
|---|---|---|---|---|---|
| 1. Brand & Onboarding / Entry | 2 | 0 | 2 | 2 | 4 |
| 2. Ingestion & Capture Flow | 3 | 0 | 1 | 0 | 4 |
| 3. Extraction & Review Pipeline | 6 | 0 | 0 | 0 | 6 |
| 4. Calendar & Event Details | 6 | 0 | 0 | 0 | 6 |
| 5. Settings & Functional Sub-Screens | 10 | 0 | 0 | 0 | 10 |
| 6. Account, Security & Verification Flows | 6 | 0 | 0 | 0 | 6 |
| 7. Monetization & Subscription Paywalls | 3 | 0 | 0 | 0 | 3 |
| 8. Edge States & System Handlers | 0 | 3 | 0 | 0 | 3 |
| 9. Marketing Collateral & App Store Assets | 0 | 0 | 23 | 0 | 23 |
| **Total** | **30** | **3** | **23** | **2** | **61** |

---

## 3. ID Format Analysis

### Three-Layer ID Architecture
The project employs three distinct ID naming conventions across its architecture:

| Layer | ID Format | Example | Purpose |
|---|---|---|---|
| **Reference Doc Canonical** | 32-char hex (e.g., `fbe4384a12264d05beabb17d381cb56a`) | Historical snapshot IDs from earlier catalog maps | Documentation and architecture reference |
| **Stitch Project-Relative** | 32-char hex (e.g., `16ba66e852cf4f05bdfd0def84d89899`) | Visible in Stitch canvas URLs | Active design canvas management |
| **Live Canvas Item IDs** | 32-char hex (e.g., `19890c6eccda4ab4af40606b516bfd42`) | Currently active IDs on live Stitch canvas | Runtime canvas state tracking |

### Mapping Verification
- Stitch project IDs ↔ Reference doc canonical IDs: **1:1 confirmed** for all 30 app screens
- Stitch IDs ≠ Live Canvas Item IDs: **Different numbering system** — live canvas reflects current state, project IDs are snapshots
- The tri-layer architecture explains why initial mapping attempts failed — ID format mismatch between layers

---

## 4. Category Organization

### 1. Brand & Onboarding / Entry (4 screens)
- **Home Empty State** (`fbe4384a12264d05beabb17d381cb56a`) — Default landing state, tab root
- **Pencil'd Splash Screen** (`83c1bbed375c4e64a11e4d6cf118ddcb`) — Brand introduction, web/cinematic fullscreen
- **Screen Catalog & Architecture Map** (×2) — Meta screens documenting project architecture
- **Marketing overlap**: Home Empty State also appears in Marketing Assets

### 2. Ingestion & Capture Flow (4 screens)
- **Source Chooser** (`ff3f9dc009634ef184ee1265fe01bbb8`) — Central ingestion hub, stack navigation
- **Scan Processing Progress** (`7518b065195d472b95d1de6c531f5305`) — Neural processing HUD, modal progress
- **Batch Scan Queue** (×2, v1/v2) — Queue manager, stack navigation; v2 is a duplicate
- **Screenshot Triage** also crosses into Marketing Assets

### 3. Extraction & Review Pipeline (6 screens)
- **Automatic Review** (`83b470e1c9204a508956455573bfd841`) — Tab root for background-captured items
- **Extraction Details** (`066c3f7d70c542d5a59daa1f2646e1ee`) — OCR token inspector, stack navigation
- **Review Multiple Events** (`cff09c75a5644009a91980039885eb50`) — Multi-event triage, stack navigation
- **PDF & File Review** (`055befddc2214768aca60f2ef44fc33f`) — Multi-page document viewer, stack navigation
- **Event Review & Edit** (`f81f5f07d496494d86fb5b4ddadfa74f`) — Single-event verification, stack navigation
- **No Dates Found** crosses into Edge States as fallback/error state

### 4. Calendar & Event Details (6 screens)
- **Agenda** (`f28e0e9083b14d36adb4704f55aee638`) — Tab root, timeline feed
- **Event Details** (`7407fd1d5a964b55953c301c8e917305`) — Calendar event inspector, stack navigation
- **Saved Event Detail** (`1032e689b29a47939c6c78698052bc04`) — Post-sync confirmation, stack navigation
- **Edit Event** (`9d3fb88befbb41e58764a589104c6176`) — Event form editor, stack/modal navigation
- **Reminder Schedule Editor** (`2be50785f7984d278ea209ebb04586ec`) — Notification manager, stack navigation
- **Calendar Permission Denied** crosses into Edge States as permission-prompt state

### 5. Settings & Functional Sub-Screens (10 screens)
- **Settings** (`190f858174284706925d97c3896183b4`) — Tab root, main preferences dashboard
- **Source Preferences** (`70672a6c87cb4dfda8c326199980ab26`) — Formats & OCR rules, stack navigation
- **Default Calendar** (`51e330d6e9fc4fefb81e140cd7f29838`) — Service integrations, stack navigation; crosses into Edge States
- **Notification Preferences** (`73bc7e2b84d64b6fb5b06b11f16c8821`) — Push & SMS channels, stack navigation; crosses into Edge States
- **Reminder Presets** (`743a9b3e34ca4e198f168ac427bb3dcc`) — Default cadences, stack navigation
- **Smart Suggestions** (`7b9ac49f4cb8429f89fcdbe7a385231b`) — AI model options, stack navigation
- **Privacy & Processing** (`386887cd99e644d58df555eb784e03f1`) — On-Device Neural Engine, stack navigation
- **App Preferences** (`c77e5205b8504b858b783cc58241bac7`) — UI settings, clock, localization, stack navigation
- **Help & Support** (`603036ba090a43fa89c09f56742c3c2c`) — Tutorials & FAQs, stack navigation
- **Automatic Capture** (`48e1e7cc3474407184365c4c4b876a0e`) — Background radar controls, stack navigation; crosses into Edge States

### 6. Account, Security & Verification Flows (6 screens)
- **User Profile** (`e1579dc2f4b44b999727d1d14f8aea4a`) — Account hub with tier status, stack navigation
- **Verify Phone Number** (`b668f96e38cc4d218448aa79ea087842`) — Phone registration, stack navigation
- **Enter Phone SMS Code** (`8312446ef9704f9190521c251b4d3edc`) — 6-digit PIN confirmation, stack navigation
- **Check Email Inbox** (`cb904a46e71c470e9dd4da1548a47c09`) — Magic link reader, stack navigation
- **Verification Complete** (`fd8816a0703040a7b4329f1dce6a12fc`) — Success state confirmation, stack navigation
- **Notification Permission Denied** crosses into Edge States as permission-denied state

### 7. Monetization & Subscription Paywalls (3 screens)
- **Premium Paywall** (`eab25e1f62d84bd2beb2c91eda10f328`) — Stack/modal paywall, lifetime tier added
- **Plus Paywall** (`8e693fe0c6134c9ebdb8044b362893a5`) — Stack/modal paywall, lifetime tier added
- **Manage Subscription** (`3ae5f792048947cb95c7834693829a1f`) — Tier management, stack navigation

### 8. Edge States & System Handlers (3 screens)
- **No Dates Found** (`b11a3800c14646748573e492eabbdbd2`) — Stack/error fallback when OCR detects no dates
- **Calendar Permission Denied** (`420f4607817a4ab4bf423275d8d520af`) — Permission prompt with iOS Settings CTA
- **Notification Permission Denied** (`6c55f02e2a164cee9d3d1ee03cd6e54a`) — Permission prompt with iOS Settings link

### 9. Marketing Collateral & App Store Assets (23 screens)
- **23 pure promotional/asset screens** with no functional app-screen counterpart
- Includes: App Store screenshot promos (iPhone 6.9″, iPad Pro 13″), background assets, logo files, marketing kit docs, banner ads, email newsletter headers, marketing copy/templates
- These represent the App Store listing assets and brand collateral, not in-app screens

---

## 5. Design Token & Architecture Gaps

### Missing Category Field
All 61 Stitch screen JSON objects contain only: `name`, `title`, `screenshot`, `htmlCode` — **no `category` field**. This means:
- Category assignment must be derived from reference doc ID mapping
- No automated filtering by category is possible from Stitch data alone
- Manual mapping (as performed in this audit) is required for any category-based operations

### Live Canvas Item ID Divergence
The project employs a tri-layer ID system:
1. Reference doc canonical IDs (historical snapshots)
2. Stitch project-relative IDs (current canvas state)
3. Live Canvas Item IDs (actively running canvas)

**Gap**: There is no automatic mapping layer between Stitch project IDs and Live Canvas Item IDs. The Live Canvas IDs appear to represent a newer/reorganized canvas state that may not include all historical screens.

### Cross-Category Overlap Implications
6 screens belonging to multiple categories indicates:
- The 7-domain taxonomy is **not mutually exclusive** by design
- Screens with cross-cutting concerns (permission flows, error states, fallback screens) naturally belong to multiple domains
- Any architecture redesign should consider whether to:
  - Keep cross-category assignments (current state)
  - Refactor into strictly single-category screens
  - Create a "Cross-Cutting Concerns" domain

### Marketing/Functional Split
23 of 61 screens (38%) are pure marketing/asset screens with no functional app counterpart. This suggests:
- The project historically tracked both in-app screens and App Store assets in the same system
- A future cleanup could separate these into distinct projects/databases
- The current Stitch project appears to conflate marketing collateral with functional UI screens

---

## 6. Recommendations

### Immediate Actions
1. **Update Stitch screen metadata** to include a `category` field derived from this mapping
2. **Document the tri-layer ID architecture** (reference doc canonical ↔ Stitch project-relative ↔ Live Canvas Item) for future developers
3. **Consider separating marketing assets** from functional UI screens into distinct Stitch projects or tagging systems

### Medium-Term Improvements
1. **Refactor cross-category screens** to have single primary categories, or explicitly define a "Cross-Cutting Concerns" domain
2. **Add design tokens** (colors, fonts, archetypes) to screen metadata for automated design system conformance checking
3. **Establish Live Canvas Item ID mapping** to ensure runtime state stays synchronized with project documentation

### Long-Term Architecture
1. **Separate marketing and functional tracking**: Create two Stitch projects — one for in-app UI screens, one for App Store assets and marketing collateral
2. **Implement category enforcement**: Add category validation to screen creation/edit workflows to prevent miscategorization
3. **Design system integration**: Use the mapped IDs to automate design token generation and conformance checking against the `datesnap-design-system-updated.md` specifications

---

## 7. Files Created/Modified

| File | Path | Description |
|---|---|---|
| Screen ID Mapping | `docs/plans/stitched-screen-mapping.md` | Comprehensive 61-screen mapping table with all IDs, titles, categories, and archetypes |
| Screen Manifest | `docs/plans/manifest.md` | Organized manifest of all 61 screens by 7 reference doc categories with full mapping data |
| Audit Document | `docs/plans/pencild-refresh-audit.md` | This audit document — executive summary, analysis, recommendations |

---

## Appendix A: Full Screen ID Mappings (Condensed)

### Brand & Onboarding
- `e94d669cef5a4ad5bcf0a7ed72e7e938` → `fbe4384a12264d05beabb17d381cb56a` (Home Empty State)
- `e166be75965c43b5b525bbf2a9213a7f` → `83c1bbed375c4e64a11e4d6cf118ddcb` (Splash Screen)

### Ingestion & Capture Flow
- `16ba66e852cf4f05bdfd0def84d89899` → `ff3f9dc009634ef184ee1265fe01bbb8` (Source Chooser)
- `a307a3147a1f47d7ab545178a0eabd81` → `7518b065195d472b95d1de6c531f5305` (Scan Processing Progress)
- `81223b00062b46c0a06a0c79a6b5ad60` → `662f5ef79f254460b641f03be61c00b1` (Batch Scan Queue)

### Extraction & Review Pipeline
- `b726b180de014de4a88b13d4f315f7e5` → `83b470e1c9204a508956455573bfd841` (Automatic Review)
- `f0b02ea3d50e452e91c61fe03ba087ba` → `066c3f7d70c542d5a59daa1f2646e1ee` (Extraction Details)
- `b96499d3188a4b52a2cd386e3b4e8f28` → `cff09c75a5644009a91980039885eb50` (Review Multiple Events)
- `9f640bd6ad79459898892de895391544` → `055befddc2214768aca60f2ef44fc33f` (PDF & File Review)
- `ec7fcceed7a24971ae74c7b9d0dbbca7` → `f81f5f07d496494d86fb5b4ddadfa74f` (Event Review & Edit)
- `dfbea9bc83d1466aba5974c253b4db71` → `06b14b0141ea45f6b17c298dbdb72b06` (Screenshot Triage)

### Calendar & Event Details
- `5b23fc34d25d47949a1229ac42cebfad` → `7407fd1d5a964b55953c301c8e917305` (Event Details)
- `117742cd4c37404ca2238afe1be6a047` → `2be50785f7984d278ea209ebb04586ec` (Reminder Schedule Editor)
- `d03171235a96456a9249a4daa03c7624` → `88b16e4687d644a995a3ec0c3cf854ac` (History & Archive)
- `c9534010e1114ba7bd297edc22f1c9ff` → `f28e0e9083b14d36adb4704f55aee638` (Agenda)
- `71a8a0266972488d886fc1ccb2aea981` → `9d3fb88befbb41e58764a589104c6176` (Edit Event)
- `cf306ab941854322aaf0d07d7c533a91` → `1032e689b29a47939c6c78698052bc04` (Saved Event Detail)

### Settings & Functional Sub-Screens
- `0f3874c6088b482b872bfd5b5f312eb7` → `190f858174284706925d97c3896183b4` (Settings)
- `0af7876285d64dd59f9b6f1a25285fe2` → `386887cd99e644d58df555eb784e03f1` (Privacy & Processing)
- `89f60140b09c4ad78fc9705e9dbbde84` → `7b9ac49f4cb8429f89fcdbe7a385231b` (Smart Suggestions)
- `4f7fb7c09ca442b1935ed0f729924f6b` → `73bc7e2b84d64b6fb5b06b11f16c8821` (Notification Preferences)
- `7dd0255a932141d79138f3b97a452fc9` → `70672a6c87cb4dfda8c326199980ab26` (Source Preferences)
- `e2ef8e9041a74d2fa2dd543b653fa2d3` → `743a9b3e34ca4e198f168ac427bb3dcc` (Reminder Presets)
- `5681a6bf69114d778619f925469aa25e` → `c77e5205b8504b858b783cc58241bac7` (App Preferences)
- `f3d0483edc2a43438cfa34e37205fecd` → `51e330d6e9fc4fefb81e140cd7f29838` (Default Calendar)
- `22898da21df9424ab424cfbfef45fd03` → `48e1e7cc3474407184365c4c4b876a0e` (Automatic Capture)
- `10feefa51f1a40699d59b22ebea70b22` → `b64f0f2b53f54ecb94ddd3c19a654485` (Verify Email Address)

### Account, Security & Verification Flows
- `a77a1855fc904c529b04aada1d00c5a7` → `fd8816a0703040a7b4329f1dce6a12fc` (Verification Complete)
- `1e01d494177a4ab4bff2ef6014d788e4` → `b668f96e38cc4d218448aa79ea087842` (Verify Phone Number)
- `b01ff3968f5a41e091549e94981e6563` → `8312446ef9704f9190521c251b4d3edc` (Enter Phone SMS Code)
- `cf05d2e2cc52430093ad092c8a62d76c` → `cb904a46e71c470e9dd4da1548a47c09` (Check Email Inbox)
- `80ec0320a47a4f6f9ff8c98bec1e6a5d` → `e1579dc2f4b44b999727d1d14f8aea4a` (User Profile)
- `7098b1759cde482ab97dfcbbdeb9ccfc` → `603036ba090a43fa89c09f56742c3c2c` (Help & Support)

### Monetization & Subscription Paywalls
- `b049d1c4c3e7491f867bc5ebd8224b99` → `eab25e1f62d84bd2beb2c91eda10f328` (Premium Paywall)
- `7296411f5d9446e3b334a9ab09abf898` → `8e693fe0c6134c9ebdb8044b362893a5` (Plus Paywall)
- `b9eabf1d24fb4c7f9e392cd9d58159e3` → `3ae5f792048947cb95c7834693829a1f` (Manage Subscription)

### Edge States & System Handlers
- `9cd18db50bf64b8a80431e483052c853` → `b11a3800c14646748573e492eabbdbd2` (No Dates Found)
- `8e89625cc96f49c48ebed8bfef75b9b0` → `420f4607817a4ab4bf423275d8d520af` (Calendar Permission Denied)
- `6eb304b327e6400ba203aa40d9798a85` → `6c55f02e2a164cee9d3d1ee03cd6e54a` (Notification Permission Denied)

### Marketing & App Store Assets (selected)
- `c260982726f743cd973a064579946822` → App Store slide (iPhone 6.9″)
- `5d72d1bfbe5445ddbd33416047296fce` → App Store slide (iPad Pro 13″)
- `65a70a58868f45a6b2af0f64ff6ebc54` → Banner ad (16:9)
- `a71e5d0aabda40b2ac31b4b9d953dc1e` → Marketing Copy & Email Template
- `ec6850f39a674f65951ab4313389a227` → Email newsletter header banner (16:9)

---

*End of Audit Document*