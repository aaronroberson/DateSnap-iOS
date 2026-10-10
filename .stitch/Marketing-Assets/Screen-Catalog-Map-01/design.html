# Pencil'd — Comprehensive Screen Architecture & Catalog

This document catalogues all interface screens designed for **Pencil'd**, including their Canvas Item IDs, titles, functional descriptions, navigation archetypes, and bidirectional hierarchical relationships (parent screen to sub-screens, and sub-screens back to parents).

---

## Architecture Overview & Core Taxonomy

The app is architected into 7 primary structural domains:
1. **Brand & Onboarding / Entry** (Splash & Home Base)
2. **Ingestion & Capture Flow** (Source Chooser, Camera, Scan, and Queue)
3. **Extraction & Review Pipeline** (OCR Parsing, Verification, Multi-Event Triage)
4. **Calendar & Event Details** (Agenda, Single Event Inspector, Reminder Schedule)
5. **Settings & Functional Sub-Screens** (Preferences, Capture Rules, Defaults)
6. **Account, Security & Verification Flows** (Profile, Phone Verification, Email Verification)
7. **Monetization & Subscription Paywalls** (Plus, Premium, Subscription Management)

---

## 1. Brand & Onboarding

### Home Empty State
ID: b9b594589f1f473db2ea29b5f9a49ec7
- **Archetype**: Tab Root (`mobile_tab`)
- **Description**: The default landing state for first-time or clean-slate users. Features the brand header, an illustration/crest, a clear value proposition explaining neural scheduling, a prominent *"Capture Schedule"* primary button, and the 4-tab bottom navigation bar (Home, Agenda, Review, Settings).
- **Sub-Screens & Connected Destinations**:
  - `Source Chooser / Capture Events` (ID: 106866fbc60e4157a12de509de95d1b5) — launched via the central primary CTA.
  - `Agenda` (ID: a693440c83a04507bf73b0143d9d004e) — navigated via the bottom tab bar.
  - `Automatic Review` (ID: b1d40ba9bbee4b75beebe4fcdf1daf63) — navigated via the bottom tab bar.
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8) — navigated via the bottom tab bar.
- **Parent Screen**: Root navigation level.

### Pencil'd Splash Screen
ID: 18a6a8bea14a43139d6ca46c69d62980
- **Archetype**: Web / Cinematic Fullscreen (`web_standard`)
- **Description**: High-impact brand introduction featuring the Pencil'd glowing 3D app icon crest, wordmark, tagline (*"Scanned. Reviewed. Pencil'd."*), and dynamic orbital constellation lines on midnight dark canvas. Used for launch sequence, onboarding transitions, and App Store presentations.
- **Sub-Screens & Connected Destinations**:
  - `Home Empty State` (ID: b9b594589f1f473db2ea29b5f9a49ec7) — initial destination after launch transition.
- **Parent Screen**: Root application entry point.

---

## 2. Ingestion & Capture Flow

### Source Chooser (Capture Events)
ID: 106866fbc60e4157a12de509de95d1b5
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: The central ingestion hub. Allows users to choose an input source: Camera Scanner, Photo Library, PDF/File Import, Screenshot Radar sync, or manual event creation. Displays interactive demo flyer shortcut.
- **Sub-Screens & Connected Destinations**:
  - `Scan Processing Progress` (ID: 9e7bbc90ad704b259c9e45288f82e22b) — invoked upon capturing or selecting an image.
  - `PDF & File Review` (ID: 4d007694af044b58a12ed7bc4af7ea02) — invoked when selecting "PDF or file import".
  - `Screenshot Triage` (ID: b289f659ceee4e4ba1535e23eecb36b8) — invoked when tapping "Screenshots & Camera Roll".
  - `Edit Event` (ID: 8d70f9b4a8744c5da0c5bbab7d39ea71) — invoked via the "Create an event" card.
  - `Batch Scan Queue` (ID: 2a635408bafc4ed5865b044a7875fca2) — invoked when multiple files or photos are selected simultaneously.
- **Parent Screen**:
  - `Home Empty State` (ID: b9b594589f1f473db2ea29b5f9a49ec7)

### Scan Processing Progress
ID: 9e7bbc90ad704b259c9e45288f82e22b
- **Archetype**: Stack / Modal Progress (`mobile_stack`)
- **Description**: Real-time on-device neural processing HUD. Displays stage indicators: Neural OCR, Entity Extraction, Date Parsing, Conflict Check, and confidence meter with progress bar.
- **Sub-Screens & Connected Destinations**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) — destination upon successful single-event extraction.
  - `Review Multiple Events` (ID: f1aa01177a3c48f0b2f1443f67947742) — destination if multiple events are detected.
  - `No Dates Found` (ID: e99d207014af45eb92f5627a1a4fc59e) — fallback edge state if OCR finds no scheduling entities.
- **Parent Screen**:
  - `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5)

### Batch Scan Queue
ID: 2a635408bafc4ed5865b044a7875fca2
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Manages concurrent, multi-image or multi-document ingestion queues. Shows active background OCR status, queue thumbnails, success counters, and batch actions.
- **Sub-Screens & Connected Destinations**:
  - `Review Multiple Events` (ID: f1aa01177a3c48f0b2f1443f67947742) — bulk review destination once the batch finishes parsing.
  - `Extraction Details` (ID: 16dd3424b6c84bb5a5f637d1ee032294) — inspect individual document batch items.
- **Parent Screen**:
  - `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5)

---

## 3. Extraction & Review Pipeline

### Event Review & Edit (Verification Step)
ID: 6da8284156904bf19c27cac65e31a3fa
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: High-fidelity single-event review inspector. Displays side-by-side or stacked original flyer crop alongside AI-parsed fields (Title, Date, Time, Location, Confidence Score 99.4%, Radar Conflict checks), a checkbox for opting to add the original source image to Apple Calendar notes, and the primary "Save to Calendar" CTA.
- **Sub-Screens & Connected Destinations**:
  - `Edit Event` (ID: 8d70f9b4a8744c5da0c5bbab7d39ea71) — tapped to adjust title, start/end time, or location manually.
  - `Reminder Schedule Editor` (ID: 3fc839ce40034ecdb696951c33dd2e0f) — tapped to configure custom push/SMS notifications.
  - `Saved Event Detail` (ID: f7c404846bbd4c94a7b370e08df9dd35) — reached after confirming "Save to Calendar".
  - `Extraction Details` (ID: 16dd3424b6c84bb5a5f637d1ee032294) — accessed to inspect raw OCR tokens and bounding boxes.
- **Parent Screen**:
  - `Scan Processing Progress` (ID: 9e7bbc90ad704b259c9e45288f82e22b) or `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5)

### Review Multiple Events
ID: f1aa01177a3c48f0b2f1443f67947742
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Multi-event triage interface for schedules, semester syllabi, sports calendars, or conference agendas containing multiple events. Features batch selection checkboxes, subtle ambient card gradient selection states (no left borders), conflict badges, and a "Pencil In All Selected" bulk action.
- **Sub-Screens & Connected Destinations**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) — tapped on any single card to fine-tune that event in isolation.
  - `Agenda` (ID: a693440c83a04507bf73b0143d9d004e) — destination after batch-saving events.
- **Parent Screen**:
  - `PDF & File Review` (ID: 4d007694af044b58a12ed7bc4af7ea02) or `Batch Scan Queue` (ID: 2a635408bafc4ed5865b044a7875fca2)

### Automatic Review
ID: b1d40ba9bbee4b75beebe4fcdf1daf63
- **Archetype**: Tab Root (`mobile_tab`)
- **Description**: Dedicated tab for background-captured items (e.g., from iOS Share Sheet, Screenshot Radar, or synced iCloud files) waiting for user verification before pushing into Apple Calendar.
- **Sub-Screens & Connected Destinations**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) — inspect an individual pending item.
  - `Review Multiple Events` (ID: f1aa01177a3c48f0b2f1443f67947742) — bulk approve pending items.
- **Parent Screen**: Root navigation tab.

### Extraction Details
ID: 16dd3424b6c84bb5a5f637d1ee032294
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Deep inspection view displaying parsed raw text blocks, OCR bounding overlays, on-device model confidence scores, detected timezones, and syntax tags.
- **Sub-Screens & Connected Destinations**:
  - Returns to `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa).
- **Parent Screen**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa)

### PDF & File Review
ID: 4d007694af044b58a12ed7bc4af7ea02
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Multi-page document review canvas (e.g. academic syllabi, multi-day sports itineraries). Includes an interactive thumbnail carousel of pages, parsed event lists per page, and page-range selectors.
- **Sub-Screens & Connected Destinations**:
  - `Review Multiple Events` (ID: f1aa01177a3c48f0b2f1443f67947742) — tapped to batch-import all extracted items across all inspected pages.
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) — tapped to review an individual item from a specific page.
- **Parent Screen**:
  - `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5)

### Screenshot Triage
ID: b289f659ceee4e4ba1535e23eecb36b8
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Review queue for flyers, concert announcements, and group chat invites detected automatically in the user's photo gallery by the on-device Background Screenshot Radar.
- **Sub-Screens & Connected Destinations**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) — tapped to confirm and pencil in an individual screenshot.
  - `Automatic Capture` (ID: 39cb36095b0b4004bfcb7427b7b71ab3) — quick gear shortcut to configure screenshot monitoring preferences.
- **Parent Screen**:
  - `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5)

---

## 4. Calendar & Event Details

### Agenda
ID: a693440c83a04507bf73b0143d9d004e
- **Archetype**: Tab Root (`mobile_tab`)
- **Description**: The primary agenda and calendar timeline tab. Chronological feed of verified pencil'd events, filterable by month/day/category, indicating sync status with Apple Calendar and iCloud.
- **Sub-Screens & Connected Destinations**:
  - `Event Details` (ID: a6562adcb25246df9845b3e8bfe3863a) — tapped to inspect any calendar event.
  - `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5) — floating "+" or camera icon to capture another schedule.
- **Parent Screen**: Root navigation tab.

### Event Details
ID: a6562adcb25246df9845b3e8bfe3863a
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Detail sheet for an existing or scheduled calendar event. Displays date, time, duration, location map, notes, linked source flyer attachment, and conflict indicators.
- **Sub-Screens & Connected Destinations**:
  - `Edit Event` (ID: 8d70f9b4a8744c5da0c5bbab7d39ea71) — opens editable fields for modifying title, dates, or notes.
  - `Reminder Schedule Editor` (ID: 3fc839ce40034ecdb696951c33dd2e0f) — opens reminder settings for this specific event.
- **Parent Screen**:
  - `Agenda` (ID: a693440c83a04507bf73b0143d9d004e)

### Saved Event Detail
ID: f7c404846bbd4c94a7b370e08df9dd35
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Confirmation view immediately following successful calendar sync. Displays event snapshot, verified timing reasoning, active reminder pills, a prominent *"Share calendar event"* button, and options to return to Agenda.
- **Sub-Screens & Connected Destinations**:
  - `Reminder Schedule Editor` (ID: 3fc839ce40034ecdb696951c33dd2e0f) — modify reminder alerts directly.
  - `Agenda` (ID: a693440c83a04507bf73b0143d9d004e) — return to primary calendar view.
- **Parent Screen**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa)

### Edit Event
ID: 8d70f9b4a8744c5da0c5bbab7d39ea71
- **Archetype**: Stack / Modal Navigation (`mobile_stack`)
- **Description**: Full editing form for event metadata: Event Title, All-Day toggle, Start & End Date/Time pickers, Time Zone selector, Location address input, Target Calendar picker, and notes. Includes "Save Changes" and "Discard changes" controls.
- **Sub-Screens & Connected Destinations**:
  - Returns to `Event Details` (ID: a6562adcb25246df9845b3e8bfe3863a) or `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa).
- **Parent Screen**:
  - `Event Details` (ID: a6562adcb25246df9845b3e8bfe3863a) or `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa)

### Reminder Schedule Editor (Notification Settings)
ID: 3fc839ce40034ecdb696951c33dd2e0f
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Granular reminder and notification manager. Displays breadcrumb `• SETTINGS - NOTIFICATIONS`, event timing summary, push alert cadence selectors (At time of event, 15 min, 1 hr, 1 day before), and an uneditable phone number card for SMS alert dispatches with custom offset selection (default 2 hours before).
- **Sub-Screens & Connected Destinations**:
  - `Verify Phone Number` (ID: d0a5c0b571a5465fb0af5f5ab9b918c4) — inline link ("Update phone number") to manage SMS dispatch destination.
  - `Reminder Presets` (ID: 12af69dd798f4ebab1c88d2b82833f01) — navigate to global default reminder rules.
- **Parent Screen**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) or `Event Details` (ID: a6562adcb25246df9845b3e8bfe3863a)

### History & Archive
ID: 5283c1cdc59f42e996e591a882c7e985
- **Archetype**: Tab Root / Management Screen (`mobile_tab`)
- **Description**: Archive repository of all past scanned materials, flyers, receipts, and imported PDF schedules. Allows search, filter by extraction source, and re-extraction of expired events.
- **Sub-Screens & Connected Destinations**:
  - `Extraction Details` (ID: 16dd3424b6c84bb5a5f637d1ee032294) — re-open raw extraction data for any archived document.
- **Parent Screen**: Root navigation tab / Settings sub-view.

---

## 5. Settings & Functional Sub-Screens

### Settings (Main Hub)
ID: f7edcd0799ff4c5380b269ca349bdda8
- **Archetype**: Tab Root (`mobile_tab`)
- **Description**: Top-level account and preferences dashboard. Houses sections for Account/Profile, Ingestion & Automation, Notifications, Calendars, Intelligence Models, Subscription status, and App Support.
- **Sub-Screens & Connected Destinations**:
  - `User Profile` (ID: 42b6997581604c65bb98da78c8142feb) — tapped on user profile header card.
  - `Automatic Capture` (ID: 39cb36095b0b4004bfcb7427b7b71ab3) — tapped on "Automatic Capture" row.
  - `Source Preferences` (ID: 47a62b99de0d4ef2a1ac90756c08b1da) — tapped on "Source Priorities & Formats".
  - `Default Calendar` (ID: 5554b91b29ff42f9b944397f86f20856) — tapped on "Default Calendar & Accounts".
  - `Notification Preferences` (ID: 08b3cf6a4166442cb9c183b2ea0c647c) — tapped on "Notification & SMS Alerts".
  - `Reminder Presets` (ID: 12af69dd798f4ebab1c88d2b82833f01) — tapped on "Default Reminder Intervals".
  - `Smart Suggestions` (ID: 4b3241d0c6294807a2acc080f59fbf0e) — tapped on "AI Intelligence & Conflict Radar".
  - `Privacy & Processing` (ID: f9d410b773ed4063bf5bdea1ca1603d2) — tapped on "On-Device Neural Vault".
  - `Manage Subscription` (ID: 1db89655bfdd493dad9c756b5f6f8389) — tapped on subscription status badge.
  - `Help & Support` (ID: 98e6b90284dc42c7a63bd45b97130d3c) — tapped on "Help & Support Center".
  - `App Preferences` (ID: 4a5c6b75b9834ecbb0a1f1959fe14f38) — tapped on "Appearance & Localization".
- **Parent Screen**: Root navigation tab.

### Automatic Capture
ID: 39cb36095b0b4004bfcb7427b7b71ab3
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Configuration for passive schedule detection: Background Screenshot Radar toggles, camera roll auto-indexing frequency, clipboard auto-paste detection, and battery optimization modes.
- **Sub-Screens & Connected Destinations**:
  - `Screenshot Triage` (ID: b289f659ceee4e4ba1535e23eecb36b8) — view caught screenshot items.
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Source Preferences
ID: 47a62b99de0d4ef2a1ac90756c08b1da
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Settings to order preferred capture sources, enable/disable specific format parsers (PDF, PNG, Apple Notes, WhatsApp forwarded fliers), and configure image compression for faster on-device OCR.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Default Calendar
ID: 5554b91b29ff42f9b944397f86f20856
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Account linking and target selector for Apple Calendar, iCloud, Google Calendar, and Microsoft Outlook. Lets users pick default color, personal vs work targets, and calendar write permissions.
- **Sub-Screens & Connected Destinations**:
  - `Calendar Permission Denied` (ID: c22e615e3fff46058bdffef860473f2b) — triggered if OS permissions are revoked.
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Notification Preferences
ID: 08b3cf6a4166442cb9c183b2ea0c647c
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Master controls for push alerts, badge counts, sound triggers, Sunday night weekly agenda briefings, and SMS text reminder channels.
- **Sub-Screens & Connected Destinations**:
  - `Notification Permission Denied` (ID: 5f65350a6bda4ceeb2cd795f41691e84) — triggered if iOS push alert permission is denied.
  - `Verify Phone Number` (ID: d0a5c0b571a5465fb0af5f5ab9b918c4) — manage mobile SMS channel.
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Reminder Presets
ID: 12af69dd798f4ebab1c88d2b82833f01
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Template manager for default alert intervals pre-applied to newly scanned events (e.g. 1 hour before for casual meetups, 24 hours before for exams/flights, 2 hours before via SMS).
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Smart Suggestions
ID: 4b3241d0c6294807a2acc080f59fbf0e
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: AI parameter customization: Conflict Radar sensitivity threshold, intelligent travel-time estimation, duplicate event merging, and academic course code auto-tagging.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Privacy & Processing
ID: f9d410b773ed4063bf5bdea1ca1603d2
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Security controls certifying 100% on-device neural processing via Apple Neural Engine. Allows toggles for iCloud Keychain enclave sync, cache clearing, and local biometric lock (FaceID).
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### App Preferences
ID: 4a5c6b75b9834ecbb0a1f1959fe14f38
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: General app interface configurations: First day of week (Sunday vs Monday), 12h vs 24h clock, app icon variant picker, and haptic feedback intensity.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Help & Support
ID: 98e6b90284dc42c7a63bd45b97130d3c
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Support center featuring searchable FAQ guides, sample flyer scanning tutorials, diagnostics export, bug reporting, and direct contact link to the Pencil'd engineering team.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

---

## 6. Account, Security & Verification Flows

### User Profile
ID: 42b6997581604c65bb98da78c8142feb
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Member identity hub displaying avatar, Apple ID link, active subscription badge (*Premium Pro Tier*), connected phone and email channels, sync statistics (e.g. 142 schedules pencil'd), and sign-out controls.
- **Sub-Screens & Connected Destinations**:
  - `Verify Phone Number` (ID: d0a5c0b571a5465fb0af5f5ab9b918c4) — tapped on Phone status row to link/update SMS number.
  - `Verify Email Address` (ID: a1ca8221b42d4cabbbfc391386ee8dae) — tapped on Email status row to link/update cloud backup address.
  - `Manage Subscription` (ID: 1db89655bfdd493dad9c756b5f6f8389) — tapped on subscription tier badge.
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Verify Phone Number
ID: d0a5c0b571a5465fb0af5f5ab9b918c4
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Phone number entry screen. Includes country code selector (`+1 🇺🇸`), formatted phone number field, delivery method selector (SMS Text vs WhatsApp), and Zero-Spam Privacy Guarantee card.
- **Sub-Screens & Connected Destinations**:
  - `Enter Phone SMS Code` (ID: 5f61ef6e8f1945e69b1b68a2b951919f) — invoked after tapping "Send Verification Code".
- **Parent Screen**:
  - `User Profile` (ID: 42b6997581604c65bb98da78c8142feb) or `Reminder Schedule Editor` (ID: 3fc839ce40034ecdb696951c33dd2e0f)

### Enter Phone SMS Code
ID: 5f61ef6e8f1945e69b1b68a2b951919f
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: 6-digit confirmation code verification screen. Features iOS Messages AutoFill shortcut pill (`849-204`), 6 individual input digit cells with active cursor indicator, resend timer countdown, and AES-256 session indicator.
- **Sub-Screens & Connected Destinations**:
  - `Verification Complete` (ID: fbcb88a478634159b763552ecfe6d591) — triggered upon entering the correct 6-digit PIN.
  - `Verify Phone Number` (ID: d0a5c0b571a5465fb0af5f5ab9b918c4) — inline "Edit phone number" to return back.
  - `Verify Email Address` (ID: a1ca8221b42d4cabbbfc391386ee8dae) — "Use Email Verification Instead" fallback button.
- **Parent Screen**:
  - `Verify Phone Number` (ID: d0a5c0b571a5465fb0af5f5ab9b918c4)

### Verify Email Address
ID: a1ca8221b42d4cabbbfc391386ee8dae
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Email linking screen. Features email address input field, quick autocomplete domain chips (`@icloud.com`, `@gmail.com`, `@outlook.com`), toggles for Weekly Agenda Briefing and Extraction Receipts, and End-to-End Encrypted Sync note.
- **Sub-Screens & Connected Destinations**:
  - `Check Email Inbox` (ID: c2b56e6800d5470ca7de29d832628a1e) — invoked after tapping "Send Verification Link & Code".
- **Parent Screen**:
  - `User Profile` (ID: 42b6997581604c65bb98da78c8142feb)

### Check Email Inbox
ID: c2b56e6800d5470ca7de29d832628a1e
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Magic link instruction screen. Displays animated/gradient card with an "Open Mail App" primary action, fallback 6-digit manual code input fields, 15-minute expiration timer, and resend countdown.
- **Sub-Screens & Connected Destinations**:
  - `Verification Complete` (ID: fbcb88a478634159b763552ecfe6d591) — triggered when magic link is tapped or 6-digit code is verified.
  - `Verify Email Address` (ID: a1ca8221b42d4cabbbfc391386ee8dae) — inline "Change email address" link.
- **Parent Screen**:
  - `Verify Email Address` (ID: a1ca8221b42d4cabbbfc391386ee8dae)

### Verification Complete
ID: fbcb88a478634159b763552ecfe6d591
- **Archetype**: Stack Navigation / Confirmation (`mobile_stack`)
- **Description**: Celebratory security success screen. Features glowing pencil checkmark crest, status pills for live SMS alerts and encrypted cloud backup, feature unlock checklist, and routing CTAs.
- **Sub-Screens & Connected Destinations**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8) / `User Profile` (ID: 42b6997581604c65bb98da78c8142feb) — via "Return to Settings".
  - `Agenda` (ID: a693440c83a04507bf73b0143d9d004e) — via "Go to Calendar Agenda".
- **Parent Screen**:
  - `Enter Phone SMS Code` (ID: 5f61ef6e8f1945e69b1b68a2b951919f) or `Check Email Inbox` (ID: c2b56e6800d5470ca7de29d832628a1e)

---

## 7. Monetization & Subscription Paywalls

### Premium Paywall
ID: ed8085a553da4797a6db821784ce6d0d
- **Archetype**: Stack / Modal Paywall (`mobile_stack`)
- **Description**: Flagship top-tier upgrade sheet. Highlights Unlimited Neural OCR (99.8% semantic accuracy), Multi-Page Syllabi & 50-page PDFs, Background Screenshot Radar, and Conflict Radar. Three-tier membership selector: Annual ($29.99/yr with 7-day trial), Monthly ($4.99/mo), and Lifetime Access ($79.99 one-time).
- **Sub-Screens & Connected Destinations**:
  - `Manage Subscription` (ID: 1db89655bfdd493dad9c756b5f6f8389) — post-purchase management view.
  - Returns to the calling feature screen upon dismissal or purchase completion.
- **Parent Screen**:
  - Triggered across `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5), `PDF & File Review` (ID: 4d007694af044b58a12ed7bc4af7ea02), `User Profile` (ID: 42b6997581604c65bb98da78c8142feb), or `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8).

### Plus Paywall
ID: c99d526574b14678ba53547906f6101e
- **Archetype**: Stack / Modal Paywall (`mobile_stack`)
- **Description**: Mid-tier consumer upgrade sheet. Offers entry-level perks (expanded monthly scans, custom notification offsets). Configured with Annual, Monthly, and Lifetime Access ($39.99 one-time) tiers.
- **Sub-Screens & Connected Destinations**:
  - `Premium Paywall` (ID: ed8085a553da4797a6db821784ce6d0d) — upgrade comparison link to Top Tier.
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8)

### Manage Subscription
ID: 1db89655bfdd493dad9c756b5f6f8389
- **Archetype**: Stack Navigation (`mobile_stack`)
- **Description**: Account subscription settings. Shows active renewal dates, plan tier switcher (Monthly, Annual, Lifetime), billing history receipt links, and link to Apple ID App Store Subscriptions.
- **Sub-Screens & Connected Destinations**:
  - `Premium Paywall` (ID: ed8085a553da4797a6db821784ce6d0d) — upgrade action for users currently on Plus or Free tiers.
- **Parent Screen**:
  - `Settings` (ID: f7edcd0799ff4c5380b269ca349bdda8) or `User Profile` (ID: 42b6997581604c65bb98da78c8142feb)

---

## 8. Edge States & System Handlers

### No Dates Found
ID: e99d207014af45eb92f5627a1a4fc59e
- **Archetype**: Stack Navigation / Error (`mobile_stack`)
- **Description**: Fallback state when OCR scans an image or document but identifies no valid event dates or timestamps. Offers hints (glare reduction, better lighting), manual crop tool, or fallback manual event creation.
- **Sub-Screens & Connected Destinations**:
  - `Source Chooser` (ID: 106866fbc60e4157a12de509de95d1b5) — retry scan with a different source or photo.
  - `Edit Event` (ID: 8d70f9b4a8744c5da0c5bbab7d39ea71) — proceed with manual entry using extracted image text.
- **Parent Screen**:
  - `Scan Processing Progress` (ID: 9e7bbc90ad704b259c9e45288f82e22b)

### Calendar Permission Denied
ID: c22e615e3fff46058bdffef860473f2b
- **Archetype**: Stack Navigation / Permission (`mobile_stack`)
- **Description**: Informative system barrier screen when iOS Calendar access is toggled off. Explains why Pencil'd requires write access to write events without manual copying, accompanied by a direct "Open iOS Settings" deep link.
- **Sub-Screens & Connected Destinations**:
  - `Default Calendar` (ID: 5554b91b29ff42f9b944397f86f20856) — re-attempt connection once granted.
- **Parent Screen**:
  - `Event Review & Edit` (ID: 6da8284156904bf19c27cac65e31a3fa) or `Default Calendar` (ID: 5554b91b29ff42f9b944397f86f20856)

### Notification Permission Denied
ID: 5f65350a6bda4ceeb2cd795f41691e84
- **Archetype**: Stack Navigation / Permission (`mobile_stack`)
- **Description**: Informative barrier screen when iOS Push Notifications are disabled. Explains the impact on departure alarms and conflict alerts, with a one-tap deep link to iOS Notification Settings.
- **Sub-Screens & Connected Destinations**:
  - `Notification Preferences` (ID: 08b3cf6a4166442cb9c183b2ea0c647c) — return to preferences after enabling.
- **Parent Screen**:
  - `Notification Preferences` (ID: 08b3cf6a4166442cb9c183b2ea0c647c) or `Reminder Schedule Editor` (ID: 3fc839ce40034ecdb696951c33dd2e0f)

---

## Supplementary Desktop Marketing Assets

### Marketing Copy & Email Template
ID: 2ddd181a8401408790fe6e3fed8fc9be
- **Device**: DESKTOP
- **Description**: Comprehensive launch marketing presentation and HTML email template embedding the Pencil'd 3D icon banner, value proposition headlines, feature highlight pills, social media copy packs, and search ad headlines.
- **Parent Screen**: Standalone promotional collateral.
