# Pencil'd full visual refresh — implementation plan

Companion to [`2026-10-10-pencild-redesign-plan.md`](2026-10-10-pencild-redesign-plan.md) (spec + traceability matrix). This plan executes its Phase 1–3 reskin.

The full visual-refresh scope now includes Settings/Profile surfaces and
iPad/adaptive layouts alongside the core flows below. Implementation work has
landed in the shared checkout; this plan records the integrated state and the
verification still required.

**Decisions (user, 2026-10-10)**
- **Scope:** reskin every screen, plus build the Stitch screens that existing services can honestly back.
- **Tabs:** four tabs (Home, Agenda, Review, Settings). History moves under Agenda and Settings.
- **Font:** bundle Plus Jakarta Sans.

**Not built:** accounts and verification, SMS, camera viewfinder, manual crop, share extension, conflict resolver, background Radar, Smart Suggestions, and App Preferences. (A Lifetime purchase was added on 2026-10-13 as an introductory offer; see audit §7.8.)
- No UI for these, and no copy that promises them.
- Stitch-only rows (e.g. Source Preferences, the profile avatar menu) are dropped or pointed at real destinations.

## Implementation phases

### Phase 1 — Foundation (one commit; everything else builds on it)
1. **Font**
   - Add Plus Jakarta Sans variable or static TTFs (OFL) under `Resources/Fonts/`; get them from Google Fonts or the github.com/tokotype release.
   - Register them in `project.yml`: resources plus `UIAppFonts` in the Info.plist properties. Then run `xcodegen generate`.
   - Include `OFL.txt`.
2. **Tokens.** Rewrite `Theme/PencilTokens.swift` as the single source of truth:
   - The full Luminous Precision color role set (`pdSurface…pdSurfaceBright`, `pdOnSurface`, `pdOnSurfaceVariant`, `pdOutline*`, `pdPrimary`, `pdOnPrimary`, `pdPrimaryContainer`, `pdSecondary`, `pdSecondaryContainer`, `pdTertiary`, `pdTertiaryContainer`, `pdError`).
   - Status colors from the DESIGN.md prose (success `#10B981`, warning `#FFB800`, info `#3B82F6`).
   - `pdSignature` (CTA) and `pdHeadline` gradients.
   - Spacing and radius constants.
3. **Re-point the legacy layer** so all ~600 `ds*` call sites immediately take on the new look:
   - `Colors.swift`: alias the `ds*` colors to `pd*` roles.
     - `dsBackground` → surface
     - `dsPrimary` → primary
     - `dsSecondary` → secondary
     - `dsAccent` → tertiary-container
     - `dsForeground` → on-surface
     - `dsMutedForeground` → on-surface-variant
     - `dsBorder` → white 8%
     - status colors → the new status colors
     - `dsBrandGradient` / `dsPrimaryActionGradient` → `pdSignature`
   - `Typography.swift`: map `DSTypography` roles to Jakarta via `Font.custom(_:size:relativeTo:)`, so Dynamic Type keeps working.
   - `GlassModifiers.swift` → Stitch styles:
     - `dsGlassCard`: radius 12, surface-container fill, no border.
     - `dsScreenBackground`: surface with orange/violet ambient orbs.
     - `DSPrimaryButtonStyle`: gradient pill.
     - Secondary button: ghost style.
     - `DSConfidencePill`: icon + label + color.
     - `DSDateBadge`: recolored.
   - Delete the dead helpers: `MeshGradients.swift`, `EnhancedScrollView.swift`, and `HomeEmptyStateView.RoundedCornerBracket`. Confirm there are no callers first.
   - `AccentColor.colorset` → `#ffb68b`.
4. **New shared components** in `Views/PencilComponents.swift`:
   - `PDTopBar` (back circle, title, optional trailing)
   - `PDCard`
   - `PDIconTile`
   - `PDGroupedList` / `PDListRow` (icon tile, title, subtitle, trailing chevron/toggle/value)
   - `PDSectionHeader` and `PDEyebrow` (glowing dot)
   - `PDChip`
   - `PDToggleStyle`
   - `PDStatusBadge`

   Update `SettingsComponents.swift` to wrap these so its call sites keep working. All touch targets stay at least 44pt.
5. **Tab shell**
   - `ActiveTab` (`Models/AppState.swift:20`) goes to 4 cases: home, agenda, review, settings.
   - The History route moves:
     - Agenda "View full history" pushes `HistoryArchiveView` (Agenda gets a `NavigationStack`).
     - Add a `SettingsRoute.history` row.
     - The `alreadySaved` scan outcome and deep links that used `.history` now go to agenda→history. Update `ScanFlowViews.swift:6–42` and `HistoryArchiveView` callers.
   - `ContentView` tab bar becomes the Stitch docked bar:
     - 64pt, surface/90 + blur, top border.
     - Active tab: primary color with a glowing 32×4 indicator.
     - Review tab: badge dot when items are pending.
     - Icons: `house.fill`, `calendar`, `text.bubble`, `gearshape.fill`.
   - Restyle the toast.
6. **Gate:** build, then run the full test suite.

### Phase 2 — Core flow screens (match Stitch layout and copy; keep every behavior listed below)
- **Home** — `HomeEmptyStateView`, per `.stitch/Brand-Onboarding/Home-Screen/design.html`:
  - Header with avatar → Settings.
  - "Turn Schedules Into Events" with a gradient word, the subtitle, and a hero image (export from the screenshot or use the asset in `.stitch` if present).
  - Card stack: Recent screenshots, Photo library chips, PDF chips `.PDF/.ICS` (only show `.ICS` if import supports it, otherwise `.PDF/Images`), Create an event, Try sample flyer with a flyer preview, Private on-device card.
  - Keep the Plus/Premium gates and "No photo access needed".
  - Update `HomeBrandCopy` and its pinned test together.
- **Splash** (`PencilSplashView`):
  - Use the `Marketing-Assets/Pencild-Splash-Background` image if it's a usable asset, otherwise keep the gradient.
  - Fix the Stitch typo and keep "Scanned".
- **Review tab** (`ReviewQueueView`, per `Automatic-Review`):
  - Intro count, "You stay in control" card.
  - Chips All / High confidence (filter on the existing candidate confidence).
  - Rich cards: source thumbnail, % match, time, place, Review, and × dismiss (existing discard).
  - "Confirm all suggested (N)": only saves high-confidence candidates via the existing explicit save path, through `presentBatchReview`, so review-before-save is preserved.
  - "All caught up" empty state.
- **Scan pipeline** (`ScanProgressOverlay`, per `Scan-Processing-Progress`):
  - Full-screen stepper over the existing stages (preparing → OCR → parsing → interpretation), plus Cancel/Skip.
  - The batch overlay gets per-item progress rows, styled after `Batch-Scan-Queue` (no reorder or pause).
- **Recent screenshots** (`RecentScreenshotsView`): Stitch triage styling with chips and a select-all; scanning still happens after selection.
- **Event Review & Edit** (`EventReviewEditView`, `InterpretationReviewViews`):
  - Breadcrumb header and source card with a confidence badge.
  - Ambiguity/alternatives card in the Stitch "2-day pass detected / Switch" style.
  - Raw OCR block, "Extracted fields" grouped card, reminders row.
  - Save to Calendar gradient CTA + "See scan details" (scrolls to Why This / alternatives).
  - Remove the hardcoded blue and purple colors.
- **BatchReviewView:** cards in the same field style.
- **NoDatesFound:** Stitch copy, scan meta, "Quick tips", the three actions, raw OCR drawer.
- **Saved Event Detail:**
  - "Saved to Apple Calendar" status, date/time/location cards, Directions.
  - Source artifact image (from `ScannedAsset`), "Why Pencil'd chose this date" (stored interpretation provenance).
  - Active reminders; actions Open in Calendar / Edit / Alerts / Share / Archive (existing archive).
- **Reminder Schedule Editor:** event summary card; preset cards (existing presets); multi-tier alert list, add custom alert. No SMS and no channel picker.
- **Agenda:** Stitch idiom with grouped day sections and event cards; keep its accessibility IDs.
- **History:**
  - Stitch "Repository & Logs": search, filter chips with counts (existing filters), week/month grouping, cards with a thumbnail and confidence %, Restore/Archive.
  - Add a storage summary only if computable (count of saved scans). No fake MB or retention numbers.

### Phase 3 — Settings, plans, edges, and buildable gaps
- **Settings root** (`SettingsHubView`, per the Stitch Settings screen):
  - Eyebrow + "Settings".
  - Plan card (tier, renewal, Manage Subscription, Restore).
  - **System Permissions** (new): Photos, Calendar and Notifications status from the existing `HomeViewModel` / permission services, each opening iOS Settings or requesting access.
  - **App Defaults**: Default Calendar (now pushed), Default Reminders (pushed presets), Enhanced Interpretation.
  - History & Archive row; Privacy card; Support & Legal (Help, Terms, Privacy); version.
  - Fold in the current uncommitted `tierChipText` change.
- **Default Calendar** (new pushed screen): reuse `DefaultCalendarSection` logic; calendars grouped by `EKSource`; "What this affects" card; Reset.
- **Reminder Presets** (`ReminderSettingsView`):
  - Editable global default offsets: up to 3 alerts, presets Standard / Travel / Minimal / Never Miss It, mapped to the existing `ReminderPreset` and offsets.
  - Persist in `UserSettings` (SwiftData) with a backward-compatible default equal to today's staggered offsets.
  - Have `ReminderStrategyService` / the default reminder source read it.
  - Update `MockDataCleanupTests` and add a test.
- **Privacy Center** (`PrivacyCenterView`): sandbox hero, on-device processing statement, existing Clear Scan Text / Erase All, policy link. No telemetry or hybrid toggles.
- **Help** (`HelpFeedbackView`): concierge hero, search, popular guides, Get in Touch (email, bug, feature), diagnostics card + copy bundle.
- **AutomationSettings:** restyle as a Stitch toggle card.
- **Paywalls and Manage Plan:** Stitch layout and feature cards using real entitlements and StoreKit prices, including the Lifetime introductory offer (added 2026-10-13; see audit §7.8). Manage Plan adds a stats card only from real counts (saved events, scans).
- **Permission-denied screens:** Stitch layouts.
  - The `notificationPermissionDenied` recovery sheet is wired for single-event and batch saves when local alerts are denied. It explains the fallback and opens iOS Settings while preserving Calendar, Reminders, and scan/review behavior.
  - Keep the existing fallbacks.
- **DEBUG views:** `ScreenGallery` / `MarketingKit` / `Diagnostics` get token restyling only.

## Execution notes
- The Phase 1–3 implementation is integrated in the shared checkout.
- Keep shared files additive and preserve the behavior and data guarantees recorded below.
- Commit per feature chunk (Conventional Commits). Run the brand pre-commit hook (`./scripts/install-hooks.sh`).

## Recorded verification evidence (2026-10-11; historical artifacts)

The in-scope implementation had passed the build, test, accessibility, and
production-artifact checks recorded in the companion remediation plan at that
point in the checkout history:

- XcodeGen output, Debug builds, and Release build succeed for the supported
  iPhone 17 and iPad Pro 11-inch simulator destinations.
- Full suites report 125 tests total, 123 passed, 2 skipped, 0 failed, with no
  runtime warnings on both destinations. Result bundles:
  `/private/tmp/pencild-phase4-current-iphone.xcresult` and
  `/private/tmp/pencild-phase4-current-ipad-retry.xcresult`.
- `scripts/verify-release-content.sh --require-app`, the brand gate, and
  `git diff --check` pass. The legacy literal scan has no in-scope view matches
  for `dsPrimaryActionGradient`, `0A0E1E`, or `7CFFEA`.
- Dynamic Type XL, Reduce Motion, VoiceOver labels, and 44-point controls were
  exercised; the regular-size tablet workspace structure and touch metadata are
  covered by `TabletWorkspaceTests.swift`.

These artifacts are historical evidence, not a fresh pass for the current
working tree. Newer generic-device and simulator attempts have stopped during
asset processing because CoreSimulatorService and `simdiskimaged` are
unavailable; no current Swift compilation or simulator test result is claimed
until that host-level service is restored.

The following plan checks remain environment-limited and are recorded without
invented evidence: a positive local StoreKit restore could not be completed
because the CLI simulator did not synchronize the local catalog, and populated
iPad dual-pane Event Review/Saved Event Detail smoke was not exercised with a
live record. See
[`2026-10-11-production-readiness-remediation-plan.md`](2026-10-11-production-readiness-remediation-plan.md)
for the full evidence and integrated-state notes.

### Active implementation handoff (2026-10-13)

Schedule extraction is in progress in the shared extraction path. The current
working tree adds `ScheduleExtractor.swift`, its focused tests, and the Xcode
project references; `EventExtractionCore.extract` invokes it before the regular
single-event segmentation path. The schedule parser is intentionally not marked
complete until its tests and a supported build environment pass. The regular
date-inference path remains the fallback for single flyers and unsupported
patterns. Codebase-memory MCP was refreshed against the current checkout
(20,369 nodes / 31,211 edges; status indexed) and includes the new extraction call path and tests.

Host recheck after disk cleanup (2026-10-14): `/` reports 39 GiB available at
24% capacity. `simdiskimaged` is registered and running, but the per-user
`com.apple.CoreSimulator.CoreSimulatorService` launchd job is absent;
`xcrun simctl list runtimes` still returns connection refused. A macOS reboot
or administrator-level CoreSimulator service recovery is still required before
simulator build/test evidence can be collected.
A current generic iOS build reached Swift compilation setup but
failed during asset-catalog processing because CoreSimulatorService and
`simdiskimaged` are unavailable; no current build or test pass is claimed.
The Recent Screenshots allowance prompt now trims the selected batch when the
user chooses its deselect action, so the free-plan recovery path is actionable.
A repeat with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and
derived data at `/private/tmp/pencild-current-build-continued` exited 65 at
`CompileAssetCatalogVariant`; the same CoreSimulatorService/`simdiskimaged`
failure remains the current build boundary.
The earlier host diagnosis found the data volume at 97% (about 28 GB free);
an unprivileged `launchctl kickstart` could not restart the system
`com.apple.CoreSimulator.simdiskimaged` job. Free disk space and a host restart
or administrator-level service restart were required before retrying runtime
verification.
The current static scan across `Sources/Pencild/Views` finds no `ds*` styling
aliases or legacy `#0A0E1E`/`#7CFFEA` literals. Plus Jakarta Sans Regular,
Medium, SemiBold, Bold, and ExtraBold files plus `Resources/Fonts/OFL.txt` are
bundled and referenced by the generated project.
An Xcode `swiftc -parse` sweep also passed for all 116 Swift files under
`Sources/Pencild` and `Tests/PencildTests`; this is syntax evidence only and
does not replace the blocked build or runtime checks.

### UX review follow-up (2026-10-14)

[`docs/audits/ux-review-report.md`](../audits/ux-review-report.md) is now part
of this plan's acceptance scope. Its current-source reconciliation confirms
that free-scan visibility, over-limit deselection, discard confirmation,
detailed batch failure messages, per-card destination summaries, and
on-device progress messaging are implemented. Remaining UX work is:

- add an explicit confirmation step before bulk `Save All`;
- make actionable versus total event counts explicit;
- provide a consolidated destination summary before insertion;
- warn before dismissing a review with unsaved edits; and
- complete runtime VoiceOver checks for status badges and failure states.

The audit's merge-duplicate recommendation remains intentionally deferred;
the current “Keep separate” behavior preserves user control. Batch Review now
also confirms Save All with the actionable/total count and destination summary.
Remaining UX follow-up is runtime VoiceOver verification for status badges and
failure states; Batch Review now warns before dismissing unsaved work.

## Verification
- `xcodegen generate --spec project.yml`, then:
  ```sh
  xcodebuild -project Pencild.xcodeproj -scheme Pencild -destination 'platform=iOS Simulator,name=iPhone 17' build
  xcodebuild test -project Pencild.xcodeproj -scheme Pencild -destination 'platform=iOS Simulator,name=iPhone 17'
  ```
  Run after each phase.
- Check that `grep -rn 'dsPrimaryActionGradient\|0A0E1E\|7CFFEA'` finds no remaining legacy literals in views.
- Visual check: run in the Simulator and screenshot each screen (`xcrun simctl io booted screenshot`), comparing side-by-side with `.stitch/**/screenshot.*` for Home, Review, Event Review, Detail, Agenda, History, Settings, paywalls and edge states.
- Functional smoke test in the Simulator:
  - sample flyer → review → save to calendar → detail → alerts edit → archive in History
  - photo multi-select → batch review → Save All
  - PDF import gate → paywall
  - deep link from a notification
  - permission-denied paths
  - restore purchases (local StoreKit config)
- Accessibility: Dynamic Type XL, VoiceOver labels on icon-only buttons, 44pt targets, Reduce Motion on splash and stepper.

## Context

At the start of this refresh, only `HomeEmptyStateView` and `PencilSplashView` used the Pencil'd `pd*` tokens (`Theme/PencilTokens.swift`); every other view used the legacy theme. That legacy theme consisted of:
- `Color.ds*` from `Theme/Colors.swift`: cyan `#7CFFEA` on `#050816`
- `DSTypography` from `Theme/Typography.swift`: SF system font
- glass card, orb background, cyan buttons and confidence pill from `Theme/GlassModifiers.swift`
- `MeshGradients.swift`, which appears to be dead code
- `SettingsComponents.swift`

Usage counts: `.dsMutedForeground` 219, `.dsForeground` 141, `.dsPrimary` 126, `.dsGlassCard` 70, `.dsScreenBackground` 24.

Goal: make every existing screen match its `.stitch` design as closely as possible, without dropping any existing feature or behavior (local-first processing, review before save, StoreKit truthfulness).

The repo already has `docs/plans/2026-10-10-pencild-redesign-plan.md`, a 300-line spec with a traceability matrix in §5 and phases in §9. This plan executes its Phase 1–3 reskin.

## Canonical design system: "Luminous Precision" (all 79 Stitch screens agree)
Source: the YAML colors in `.stitch/Brand-Onboarding/Home-Screen/DESIGN.md` lines 3–50, plus the Tailwind config in the HTML. The prose palette in DESIGN.md lines 170–212 is not used by the screens; ignore it, except take its status colors (success, warning, info).

**Colors**

| Group | Role | Hex |
|---|---|---|
| Surfaces | surface | `#101127` |
| | lowest | `#0b0c22` |
| | low | `#181930` |
| | container | `#1d1e34` |
| | high | `#27283f` |
| | highest | `#32334a` |
| | bright | `#36374f` |
| Text | on-surface | `#e1e0ff` |
| | on-surface-variant | `#e0c0af` |
| Outline | outline | `#a78b7c` |
| | outline-variant | `#584235` |
| Primary | primary | `#ffb68b` |
| | on-primary | `#522300` |
| | primary-container | `#ff7a00` |
| Secondary | secondary | `#deb7ff` |
| | secondary-container | `#670fac` |
| Tertiary | tertiary | `#ffb2ba` |
| | tertiary-container | `#ff7288` |
| Error | error | `#ffb4ab` |

- CTA gradient: `#ff7a00` → `#ff7288` → `#670fac` (or `#deb7ff`).
- Headline gradient: `#ff7a00` → `#ff5277` → `#deb7ff`.

**Type:** Plus Jakarta Sans, bundled under `Resources/Fonts/` and registered in the app manifest.

| Role | Size/line | Weight |
|---|---|---|
| display | 38/44 | 800 |
| headline-xl | 30/36 | 700 |
| headline-lg | 28/36 | 700 |
| headline-md | 22 | 600 |
| headline-sm | 18 | 600 |
| body | 16/14/12 | 400 |
| label-lg / label-md | 14 / 12 | 600 |
| label-sm | 10, uppercase, +0.06em | 700 |

**Radii:** cards 12, icon tiles 8, paywall plans 16, pills full.

**Spacing:** 4/6/8/16/24/32/48; margin 16.

**Components**

| Component | Spec |
|---|---|
| Top bar | 64pt, surface/80 blur; back circle 44 + headline-sm title; avatar on the right (32pt circle, primary, person) |
| Card | surface-container 75–90%, radius 12, shadow, no border |
| Icon tile | 48pt radius 12, or 32pt radius 8 on surface-variant |
| Grouped list | surface-container-low, rows 16pt padding, divider highest/60, chevron |
| Section header | label-sm uppercase on-surface-variant/80; eyebrow variant has a glowing orange dot |
| Primary CTA | full-width pill 52–56pt, gradient, shadow primary-container/25 |
| Chips | primary/15 + primary text; neutral highest + variant text |
| Toggle | primary-container fill |
| Tab bar | docked full width, 64pt, surface/90 blur, top border; active = primary + 32×4 glowing bar |

**Icons:** Material Symbols map to SF Symbols (table to be kept in code comments where needed).

## Screen mapping (Stitch → Swift), status
(Full detail: the §5 matrix in the docs plan.)
- Home-Screen (newest) → `HomeEmptyStateView`: implemented; runtime visual comparison remains pending.
- Splash, Home-Empty-State → `PencilSplashView`: close.
- Event Details / Saved Event Detail → `SavedEventDetailView`: implemented; runtime visual comparison remains pending.
- Edit Event / Event Review & Edit → `EventReviewEditView` + `InterpretationReviewViews`: implemented; runtime visual comparison remains pending.
- Reminder Schedule Editor → `ReminderScheduleEditorView`: implemented; runtime visual comparison remains pending.
- History & Archive → `HistoryArchiveView`: implemented; runtime visual comparison remains pending.
- Automatic Review → `ScanFlowViews.ReviewQueueView`: implemented; visual runtime comparison remains pending.
- Batch Scan Queue / Scan Processing Progress → `ScanFlowViews` overlays: implemented; visual runtime comparison remains pending.
- Screenshot Triage → `RecentScreenshotsView`: implemented; visual runtime comparison remains pending.
- No Dates Found → `NoDatesFoundView`: implemented; runtime visual comparison remains pending.
- Plus / Premium / Manage → `PlusPaywallView` / `PremiumPaywallView` / `ManagePlanView`: implemented with live StoreKit pricing, purchase, and restore paths; runtime visual comparison remains pending. Keep StoreKit prices. Lifetime is offered through 2027-04-13 (audit §7.8).
- Settings root → `SettingsHubView`: implemented; runtime visual comparison remains pending.
- Default Calendar → `DefaultCalendarSection`: implemented as a pushed screen; runtime visual comparison remains pending.
- Privacy → `PrivacyCenterView`: implemented; runtime visual comparison remains pending.
- Help → `HelpFeedbackView`: implemented; runtime visual comparison remains pending.
- Reminder Presets / Notification Preferences → `ReminderSettingsView`: implemented; runtime visual comparison remains pending.
- Automatic Capture → `AutomationSettingsView`: implemented with entitlement gating; runtime visual comparison remains pending.
- Permission denied (calendar, notifications) → the respective views: implemented; runtime visual comparison remains pending.
- User Profile → `UserProfileFlowView`: implemented; runtime visual comparison remains pending.
- iPad/adaptive Event Review and Saved Detail workspaces: implemented; runtime visual comparison remains pending.
- Agenda → `AgendaView`: implemented by analogy; runtime visual comparison remains pending.
- Stitch-only, no backing feature: verification flow, Camera viewfinder, Manual crop, Share extension, Conflict resolver, PDF page picker, App Preferences, Smart Suggestions, Source Preferences, Automatic Capture radar, SMS alerts, Family Sharing.
- Tabs: the app has 4 (Home, Agenda, Review, Settings). History is pushed from Agenda, matching the current `AppState.openHistory()` route and the newest Stitch Home.

## Behaviors that must survive (from inventory)

**App shell**
- Splash callbacks set `requestPhotoPicker` / `requestFileImporter` / switch to the Review tab; Home observes them (`HomeEmptyStateView.swift:124–135`). NoDatesFound "Scan a Different Image" relies on them too.
- Single `.sheet(item: appState.activeModal)` with `AppModalScreen` (`AppState.swift:64`), plus a separate sheet for `batchReviewSession`. The Settings `NavigationStack` uses `SettingsRoute` / `settings.pendingRoute`.
- Deep links (`DeepLinkInbox` → `ContentView.openPendingDeepLink`) and the scene-activation refresh, covered by `SceneActivationRefreshTests`.
- Toast system (`AppStateToastTests`).

**Capture and Home**
- Home photo-access alert.
- Recent-screenshot thumbnails (Plus-ranked); 1-photo vs multi-photo batch scan.
- Premium-gated file import, sample flyer, `calshow://` create, "N needing review" pill, "Auto-detect with Plus" CTA.
- Scan and batch progress overlays, including "Skip — use standard result".
- `HomeBrandCopy` strings are pinned by `PencildTests.swift:28`.

**Review and save**
- Duplicate banner, ambiguity question, date swap, alternatives, Why This, provenance chips, raw OCR, View Original.
- Suggestions and actions checklist (Premium-gated); calendar and reminder-list menus; alerts editor.
- Save, Save Draft, Discard confirm; calendar-denied sheet; DEBUG diagnostics.
- BatchReview: per-event editing and destinations, Save All with retry, skipped-items card.

**Saved events**
- Detail: Directions, status, alerts, context, Open in Calendar / Edit / Alerts / Share.
- Schedule editor: presets, max 3 alerts, Reset/Discard/Sync.
- Agenda: search, date filters, archive, "View full history"; keep its accessibility IDs.
- History: status chips, smart filters (Duplicates is Premium), swipe and context actions, two-mode delete.

**Other screens**
- NoDatesFound actions.
- Settings: profile/tier, Enhanced Interpretation, reminder preview, Default Calendar, Privacy (clear / erase all), Manage plan, Restore, Help, version, DEBUG Marketing Kit.
- ManagePlan, paywalls (StoreKit prices, Restore, Terms, Privacy).
- Permission-denied screens.
