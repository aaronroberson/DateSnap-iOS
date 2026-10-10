# Pencil'd — Comprehensive Screen Architecture & Catalog

This document catalogues all interface screens designed for **Pencil'd**, including their system Screen IDs, titles, functional descriptions, navigation archetypes, and bidirectional hierarchical relationships (parent screen to sub-screens, and sub-screens back to parents).

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
- **Screen ID**: `{{DATA:SCREEN:SCREEN_89}}`
- **Shell**: `{{DATA:SHELL:SHELL_90}}` (Tab Root)
- **Description**: The default landing state for first-time or clean-slate users. Features the brand header, an illustration/crest, a clear value proposition explaining neural scheduling, a prominent *"Capture Schedule"* primary button, and the 4-tab bottom navigation bar (Home, Agenda, Review, Settings).
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser / Capture Events*) — launched via the central primary CTA.
  - `{{DATA:SCREEN:SCREEN_74}}` (*Agenda*) — navigated via the bottom tab bar.
  - `{{DATA:SCREEN:SCREEN_68}}` (*Automatic Review*) — navigated via the bottom tab bar.
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*) — navigated via the bottom tab bar.
- **Parent Screen**: Root navigation level.

### Pencil'd Splash Screen
- **Screen ID**: `{{DATA:SCREEN:SCREEN_79}}`
- **Shell**: `{{DATA:SHELL:SHELL_80}}` (Web / Cinematic Fullscreen)
- **Description**: High-impact brand introduction featuring the Pencil'd glowing 3D app icon crest, wordmark, tagline (*"Scanned. Reviewed. Pencil'd."*), and dynamic orbital constellation lines on midnight dark canvas. Used for launch sequence, onboarding transitions, and App Store presentations.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_89}}` (*Home Empty State*) — initial destination after launch transition.
- **Parent Screen**: Root application entry point.

---

## 2. Ingestion & Capture Flow

### Source Chooser (Capture Events)
- **Screen ID**: `{{DATA:SCREEN:SCREEN_87}}`
- **Shell**: `{{DATA:SHELL:SHELL_88}}` (Stack Navigation)
- **Description**: The central ingestion hub. Allows users to choose an input source: Camera Scanner, Photo Library, PDF/File Import, Screenshot Radar sync, or manual event creation. Displays interactive demo flyer shortcut.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_56}}` (*Scan Processing Progress*) — invoked upon capturing or selecting an image.
  - `{{DATA:SCREEN:SCREEN_60}}` / `{{DATA:SCREEN:SCREEN_44}}` (*PDF & File Review*) — invoked when selecting "PDF or file import".
  - `{{DATA:SCREEN:SCREEN_62}}` (*Screenshot Triage*) — invoked when tapping "Screenshots & Camera Roll".
  - `{{DATA:SCREEN:SCREEN_76}}` (*Edit Event / Create New*) — invoked via the "Create an event" card.
  - `{{DATA:SCREEN:SCREEN_46}}` / `{{DATA:SCREEN:SCREEN_52}}` (*Batch Scan Queue*) — invoked when multiple files or photos are selected simultaneously.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_89}}` (*Home Empty State*)

### Scan Processing Progress
- **Screen ID**: `{{DATA:SCREEN:SCREEN_56}}`
- **Shell**: `{{DATA:SHELL:SHELL_57}}` (Stack / Modal Progress)
- **Description**: Real-time on-device neural processing HUD. Displays stage indicators: Neural OCR, Entity Extraction, Date Parsing, Conflict Check, and confidence meter with progress bar.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) — destination upon successful single-event extraction.
  - `{{DATA:SCREEN:SCREEN_66}}` (*Review Multiple Events*) — destination if multiple events are detected.
  - `{{DATA:SCREEN:SCREEN_38}}` (*No Dates Found*) — fallback edge state if OCR finds no scheduling entities.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*)

### Batch Scan Queue
- **Screen ID**: `{{DATA:SCREEN:SCREEN_46}}` (and `{{DATA:SCREEN:SCREEN_52}}`)
- **Shell**: `{{DATA:SHELL:SHELL_47}}` / `{{DATA:SHELL:SHELL_53}}` (Stack Navigation)
- **Description**: Manages concurrent, multi-image or multi-document ingestion queues. Shows active background OCR status, queue thumbnails, success counters, and batch actions.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_66}}` (*Review Multiple Events*) — bulk review destination once the batch finishes parsing.
  - `{{DATA:SCREEN:SCREEN_58}}` (*Extraction Details*) — inspect individual document batch items.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*)

---

## 3. Extraction & Review Pipeline

### Event Review & Edit (Verification Step)
- **Screen ID**: `{{DATA:SCREEN:SCREEN_85}}`
- **Shell**: `{{DATA:SHELL:SHELL_86}}` (Stack Navigation)
- **Description**: High-fidelity single-event review inspector. Displays side-by-side or stacked original flyer crop alongside AI-parsed fields (Title, Date, Time, Location, Confidence Score 99.4%, Radar Conflict checks), a checkbox for opting to add the original source image to Apple Calendar notes, and the primary "Save to Calendar" CTA.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_76}}` (*Edit Event*) — tapped to adjust title, start/end time, or location manually.
  - `{{DATA:SCREEN:SCREEN_83}}` (*Reminder Schedule Editor*) — tapped to configure custom push/SMS notifications.
  - `{{DATA:SCREEN:SCREEN_81}}` (*Saved Event Detail*) — reached after confirming "Save to Calendar".
  - `{{DATA:SCREEN:SCREEN_58}}` (*Extraction Details*) — accessed to inspect raw OCR tokens and bounding boxes.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_56}}` (*Scan Processing Progress*) or `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*)

### Review Multiple Events
- **Screen ID**: `{{DATA:SCREEN:SCREEN_66}}`
- **Shell**: `{{DATA:SHELL:SHELL_67}}` (Stack Navigation)
- **Description**: Multi-event triage interface for schedules, semester syllabi, sports calendars, or conference agendas containing multiple events. Features batch selection checkboxes, subtle ambient card gradient selection states (no left borders), conflict badges, and a "Pencil In All Selected" bulk action.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) — tapped on any single card to fine-tune that event in isolation.
  - `{{DATA:SCREEN:SCREEN_74}}` (*Agenda*) — destination after batch-saving events.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_60}}` / `{{DATA:SCREEN:SCREEN_44}}` (*PDF & File Review*) or `{{DATA:SCREEN:SCREEN_46}}` (*Batch Scan Queue*)

### Automatic Review
- **Screen ID**: `{{DATA:SCREEN:SCREEN_68}}`
- **Shell**: `{{DATA:SHELL:SHELL_69}}` (Tab Root)
- **Description**: Dedicated tab for background-captured items (e.g., from iOS Share Sheet, Screenshot Radar, or synced iCloud files) waiting for user verification before pushing into Apple Calendar.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) — inspect an individual pending item.
  - `{{DATA:SCREEN:SCREEN_66}}` (*Review Multiple Events*) — bulk approve pending items.
- **Parent Screen**: Root navigation tab.

### Extraction Details
- **Screen ID**: `{{DATA:SCREEN:SCREEN_58}}`
- **Shell**: `{{DATA:SHELL:SHELL_59}}` (Stack Navigation)
- **Description**: Deep inspection view displaying parsed raw text blocks, OCR bounding overlays, on-device model confidence scores, detected timezones, and syntax tags.
- **Sub-Screens & Connected Destinations**:
  - Returns to `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*)

### PDF & File Review
- **Screen ID**: `{{DATA:SCREEN:SCREEN_44}}` (and `{{DATA:SCREEN:SCREEN_60}}`)
- **Shell**: `{{DATA:SHELL:SHELL_45}}` / `{{DATA:SHELL:SHELL_61}}` (Stack Navigation)
- **Description**: Multi-page document review canvas (e.g. academic syllabi, multi-day sports itineraries). Includes an interactive thumbnail carousel of pages, parsed event lists per page, and page-range selectors.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_66}}` (*Review Multiple Events*) — tapped to batch-import all extracted items across all inspected pages.
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) — tapped to review an individual item from a specific page.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*)

### Screenshot Triage
- **Screen ID**: `{{DATA:SCREEN:SCREEN_62}}`
- **Shell**: `{{DATA:SHELL:SHELL_63}}` (Stack Navigation)
- **Description**: Review queue for flyers, concert announcements, and group chat invites detected automatically in the user's photo gallery by the on-device Background Screenshot Radar.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) — tapped to confirm and pencil in an individual screenshot.
  - `{{DATA:SCREEN:SCREEN_26}}` (*Automatic Capture Settings*) — quick gear shortcut to configure screenshot monitoring preferences.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*)

---

## 4. Calendar & Event Details

### Agenda
- **Screen ID**: `{{DATA:SCREEN:SCREEN_74}}`
- **Shell**: `{{DATA:SHELL:SHELL_75}}` (Tab Root)
- **Description**: The primary agenda and calendar timeline tab. Chronological feed of verified pencil'd events, filterable by month/day/category, indicating sync status with Apple Calendar and iCloud.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_72}}` (*Event Details*) — tapped to inspect any calendar event.
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*) — floating "+" or camera icon to capture another schedule.
- **Parent Screen**: Root navigation tab.

### Event Details
- **Screen ID**: `{{DATA:SCREEN:SCREEN_72}}`
- **Shell**: `{{DATA:SHELL:SHELL_73}}` (Stack Navigation)
- **Description**: Detail sheet for an existing or scheduled calendar event. Displays date, time, duration, location map, notes, linked source flyer attachment, and conflict indicators.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_76}}` (*Edit Event*) — opens editable fields for modifying title, dates, or notes.
  - `{{DATA:SCREEN:SCREEN_83}}` (*Reminder Schedule Editor*) — opens reminder settings for this specific event.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_74}}` (*Agenda*)

### Saved Event Detail
- **Screen ID**: `{{DATA:SCREEN:SCREEN_81}}`
- **Shell**: `{{DATA:SHELL:SHELL_82}}` (Stack Navigation)
- **Description**: Confirmation view immediately following successful calendar sync. Displays event snapshot, verified timing reasoning, active reminder pills, a prominent *"Share calendar event"* button, and options to return to Agenda.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_83}}` (*Reminder Schedule Editor*) — modify reminder alerts directly.
  - `{{DATA:SCREEN:SCREEN_74}}` (*Agenda*) — return to primary calendar view.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*)

### Edit Event
- **Screen ID**: `{{DATA:SCREEN:SCREEN_76}}`
- **Shell**: `{{DATA:SHELL:SHELL_77}}` (Stack / Modal Navigation)
- **Description**: Full editing form for event metadata: Event Title, All-Day toggle, Start & End Date/Time pickers, Time Zone selector, Location address input, Target Calendar picker, and notes. Includes "Save Changes" and "Discard changes" controls.
- **Sub-Screens & Connected Destinations**:
  - Returns to `{{DATA:SCREEN:SCREEN_72}}` (*Event Details*) or `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_72}}` (*Event Details*) or `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*)

### Reminder Schedule Editor (Notification Settings)
- **Screen ID**: `{{DATA:SCREEN:SCREEN_83}}`
- **Shell**: `{{DATA:SHELL:SHELL_84}}` (Stack Navigation)
- **Description**: Granular reminder and notification manager. Displays breadcrumb `• SETTINGS - NOTIFICATIONS`, event timing summary, push alert cadence selectors (At time of event, 15 min, 1 hr, 1 day before), and an uneditable phone number card for SMS alert dispatches with custom offset selection (default 2 hours before).
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_11}}` (*Verify Phone Number*) — inline link ("Update phone number") to manage SMS dispatch destination.
  - `{{DATA:SCREEN:SCREEN_30}}` (*Reminder Presets*) — navigate to global default reminder rules.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) or `{{DATA:SCREEN:SCREEN_72}}` (*Event Details*)

### History & Archive
- **Screen ID**: `{{DATA:SCREEN:SCREEN_54}}`
- **Shell**: `{{DATA:SHELL:SHELL_55}}` (Tab Root / Management Screen)
- **Description**: Archive repository of all past scanned materials, flyers, receipts, and imported PDF schedules. Allows search, filter by extraction source, and re-extraction of expired events.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_58}}` (*Extraction Details*) — re-open raw extraction data for any archived document.
- **Parent Screen**: Root navigation tab / Settings sub-view.

---

## 5. Settings & Functional Sub-Screens

### Settings (Main Hub)
- **Screen ID**: `{{DATA:SCREEN:SCREEN_70}}`
- **Shell**: `{{DATA:SHELL:SHELL_71}}` (Tab Root)
- **Description**: Top-level account and preferences dashboard. Houses sections for Account/Profile, Ingestion & Automation, Notifications, Calendars, Intelligence Models, Subscription status, and App Support.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_64}}` (*User Profile*) — tapped on user profile header card.
  - `{{DATA:SCREEN:SCREEN_26}}` (*Automatic Capture*) — tapped on "Automatic Capture" row.
  - `{{DATA:SCREEN:SCREEN_32}}` (*Source Preferences*) — tapped on "Source Priorities & Formats".
  - `{{DATA:SCREEN:SCREEN_34}}` (*Default Calendar*) — tapped on "Default Calendar & Accounts".
  - `{{DATA:SCREEN:SCREEN_28}}` (*Notification Preferences*) — tapped on "Notification & SMS Alerts".
  - `{{DATA:SCREEN:SCREEN_30}}` (*Reminder Presets*) — tapped on "Default Reminder Intervals".
  - `{{DATA:SCREEN:SCREEN_36}}` (*Smart Suggestions*) — tapped on "AI Intelligence & Conflict Radar".
  - `{{DATA:SCREEN:SCREEN_24}}` (*Privacy & Processing*) — tapped on "On-Device Neural Vault".
  - `{{DATA:SCREEN:SCREEN_22}}` (*Manage Subscription*) — tapped on subscription status badge.
  - `{{DATA:SCREEN:SCREEN_18}}` (*Help & Support*) — tapped on "Help & Support Center".
  - `{{DATA:SCREEN:SCREEN_20}}` (*App Preferences*) — tapped on "Appearance & Localization".
- **Parent Screen**: Root navigation tab.

### Automatic Capture
- **Screen ID**: `{{DATA:SCREEN:SCREEN_26}}`
- **Shell**: `{{DATA:SHELL:SHELL_27}}` (Stack Navigation)
- **Description**: Configuration for passive schedule detection: Background Screenshot Radar toggles, camera roll auto-indexing frequency, clipboard auto-paste detection, and battery optimization modes.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_62}}` (*Screenshot Triage*) — view caught screenshot items.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Source Preferences
- **Screen ID**: `{{DATA:SCREEN:SCREEN_32}}`
- **Shell**: `{{DATA:SHELL:SHELL_33}}` (Stack Navigation)
- **Description**: Settings to order preferred capture sources, enable/disable specific format parsers (PDF, PNG, Apple Notes, WhatsApp forwarded fliers), and configure image compression for faster on-device OCR.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Default Calendar
- **Screen ID**: `{{DATA:SCREEN:SCREEN_34}}`
- **Shell**: `{{DATA:SHELL:SHELL_35}}` (Stack Navigation)
- **Description**: Account linking and target selector for Apple Calendar, iCloud, Google Calendar, and Microsoft Outlook. Lets users pick default color, personal vs work targets, and calendar write permissions.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_42}}` (*Calendar Permission Denied*) — triggered if OS permissions are revoked.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Notification Preferences
- **Screen ID**: `{{DATA:SCREEN:SCREEN_28}}`
- **Shell**: `{{DATA:SHELL:SHELL_29}}` (Stack Navigation)
- **Description**: Master controls for push alerts, badge counts, sound triggers, Sunday night weekly agenda briefings, and SMS text reminder channels.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_40}}` (*Notification Permission Denied*) — triggered if iOS push alert permission is denied.
  - `{{DATA:SCREEN:SCREEN_11}}` (*Verify Phone Number*) — manage mobile SMS channel.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Reminder Presets
- **Screen ID**: `{{DATA:SCREEN:SCREEN_30}}`
- **Shell**: `{{DATA:SHELL:SHELL_31}}` (Stack Navigation)
- **Description**: Template manager for default alert intervals pre-applied to newly scanned events (e.g. 1 hour before for casual meetups, 24 hours before for exams/flights, 2 hours before via SMS).
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Smart Suggestions
- **Screen ID**: `{{DATA:SCREEN:SCREEN_36}}`
- **Shell**: `{{DATA:SHELL:SHELL_37}}` (Stack Navigation)
- **Description**: AI parameter customization: Conflict Radar sensitivity threshold, intelligent travel-time estimation, duplicate event merging, and academic course code auto-tagging.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Privacy & Processing
- **Screen ID**: `{{DATA:SCREEN:SCREEN_24}}`
- **Shell**: `{{DATA:SHELL:SHELL_25}}` (Stack Navigation)
- **Description**: Security controls certifying 100% on-device neural processing via Apple Neural Engine. Allows toggles for iCloud Keychain enclave sync, cache clearing, and local biometric lock (FaceID).
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### App Preferences
- **Screen ID**: `{{DATA:SCREEN:SCREEN_20}}`
- **Shell**: `{{DATA:SHELL:SHELL_21}}` (Stack Navigation)
- **Description**: General app interface configurations: First day of week (Sunday vs Monday), 12h vs 24h clock, app icon variant picker, and haptic feedback intensity.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Help & Support
- **Screen ID**: `{{DATA:SCREEN:SCREEN_18}}`
- **Shell**: `{{DATA:SHELL:SHELL_19}}` (Stack Navigation)
- **Description**: Support center featuring searchable FAQ guides, sample flyer scanning tutorials, diagnostics export, bug reporting, and direct contact link to the Pencil'd engineering team.
- **Sub-Screens & Connected Destinations**:
  - None (leaf configuration sub-screen).
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

---

## 6. Account, Security & Verification Flows

### User Profile
- **Screen ID**: `{{DATA:SCREEN:SCREEN_64}}`
- **Shell**: `{{DATA:SHELL:SHELL_65}}` (Stack Navigation)
- **Description**: Member identity hub displaying avatar, Apple ID link, active subscription badge (*Premium Pro Tier*), connected phone and email channels, sync statistics (e.g. 142 schedules pencil'd), and sign-out controls.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_11}}` (*Verify Phone Number*) — tapped on Phone status row to link/update SMS number.
  - `{{DATA:SCREEN:SCREEN_15}}` (*Verify Email Address*) — tapped on Email status row to link/update cloud backup address.
  - `{{DATA:SCREEN:SCREEN_22}}` (*Manage Subscription*) — tapped on subscription tier badge.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Verify Phone Number
- **Screen ID**: `{{DATA:SCREEN:SCREEN_11}}`
- **Shell**: `{{DATA:SHELL:SHELL_12}}` (Stack Navigation)
- **Description**: Phone number entry screen. Includes country code selector (`+1 🇺🇸`), formatted phone number field, delivery method selector (SMS Text vs WhatsApp), and Zero-Spam Privacy Guarantee card.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_13}}` (*Enter Phone SMS Code*) — invoked after tapping "Send Verification Code".
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_64}}` (*User Profile*) or `{{DATA:SCREEN:SCREEN_83}}` (*Reminder Schedule Editor*)

### Enter Phone SMS Code
- **Screen ID**: `{{DATA:SCREEN:SCREEN_13}}`
- **Shell**: `{{DATA:SHELL:SHELL_14}}` (Stack Navigation)
- **Description**: 6-digit confirmation code verification screen. Features iOS Messages AutoFill shortcut pill (`849-204`), 6 individual input digit cells with active cursor indicator, resend timer countdown, and AES-256 session indicator.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_9}}` (*Verification Complete*) — triggered upon entering the correct 6-digit PIN.
  - `{{DATA:SCREEN:SCREEN_11}}` (*Verify Phone Number*) — inline "Edit phone number" to return back.
  - `{{DATA:SCREEN:SCREEN_15}}` (*Verify Email Address*) — "Use Email Verification Instead" fallback button.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_11}}` (*Verify Phone Number*)

### Verify Email Address
- **Screen ID**: `{{DATA:SCREEN:SCREEN_15}}`
- **Shell**: `{{DATA:SHELL:SHELL_16}}` (Stack Navigation)
- **Description**: Email linking screen. Features email address input field, quick autocomplete domain chips (`@icloud.com`, `@gmail.com`, `@outlook.com`), toggles for Weekly Agenda Briefing and Extraction Receipts, and End-to-End Encrypted Sync note.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_7}}` (*Check Email Inbox*) — invoked after tapping "Send Verification Link & Code".
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_64}}` (*User Profile*)

### Check Email Inbox
- **Screen ID**: `{{DATA:SCREEN:SCREEN_7}}`
- **Shell**: `{{DATA:SHELL:SHELL_8}}` (Stack Navigation)
- **Description**: Magic link instruction screen. Displays animated/gradient card with an "Open Mail App" primary action, fallback 6-digit manual code input fields, 15-minute expiration timer, and resend countdown.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_9}}` (*Verification Complete*) — triggered when magic link is tapped or 6-digit code is verified.
  - `{{DATA:SCREEN:SCREEN_15}}` (*Verify Email Address*) — inline "Change email address" link.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_15}}` (*Verify Email Address*)

### Verification Complete
- **Screen ID**: `{{DATA:SCREEN:SCREEN_9}}`
- **Shell**: `{{DATA:SHELL:SHELL_10}}` (Stack Navigation / Confirmation)
- **Description**: Celebratory security success screen. Features glowing pencil checkmark crest, status pills for live SMS alerts and encrypted cloud backup, feature unlock checklist, and routing CTAs.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*) / `{{DATA:SCREEN:SCREEN_64}}` (*User Profile*) — via "Return to Settings".
  - `{{DATA:SCREEN:SCREEN_74}}` (*Agenda*) — via "Go to Calendar Agenda".
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_13}}` (*Enter Phone SMS Code*) or `{{DATA:SCREEN:SCREEN_7}}` (*Check Email Inbox*)

---

## 7. Monetization & Subscription Paywalls

### Premium Paywall
- **Screen ID**: `{{DATA:SCREEN:SCREEN_50}}`
- **Shell**: `{{DATA:SHELL:SHELL_51}}` (Stack / Modal Paywall)
- **Description**: Flagship top-tier upgrade sheet. Highlights Unlimited Neural OCR (99.8% semantic accuracy), Multi-Page Syllabi & 50-page PDFs, Background Screenshot Radar, and Conflict Radar. Three-tier membership selector: Annual ($29.99/yr with 7-day trial), Monthly ($4.99/mo), and Lifetime Access ($79.99 one-time).
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_22}}` (*Manage Subscription*) — post-purchase management view.
  - Returns to the calling feature screen upon dismissal or purchase completion.
- **Parent Screen**:
  - Triggered across `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*), `{{DATA:SCREEN:SCREEN_44}}` (*PDF Review*), `{{DATA:SCREEN:SCREEN_64}}` (*User Profile*), or `{{DATA:SCREEN:SCREEN_70}}` (*Settings*).

### Plus Paywall
- **Screen ID**: `{{DATA:SCREEN:SCREEN_48}}`
- **Shell**: `{{DATA:SHELL:SHELL_49}}` (Stack / Modal Paywall)
- **Description**: Mid-tier consumer upgrade sheet. Offers entry-level perks (expanded monthly scans, custom notification offsets). Configured with Annual, Monthly, and Lifetime Access ($39.99 one-time) tiers.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_50}}` (*Premium Paywall*) — upgrade comparison link to Top Tier.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*)

### Manage Subscription
- **Screen ID**: `{{DATA:SCREEN:SCREEN_22}}`
- **Shell**: `{{DATA:SHELL:SHELL_23}}` (Stack Navigation)
- **Description**: Account subscription settings. Shows active renewal dates, plan tier switcher (Monthly, Annual, Lifetime), billing history receipt links, and link to Apple ID App Store Subscriptions.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_50}}` (*Premium Paywall*) — upgrade action for users currently on Plus or Free tiers.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_70}}` (*Settings*) or `{{DATA:SCREEN:SCREEN_64}}` (*User Profile*)

---

## 8. Edge States & System Handlers

### No Dates Found
- **Screen ID**: `{{DATA:SCREEN:SCREEN_38}}`
- **Shell**: `{{DATA:SHELL:SHELL_39}}` (Stack Navigation / Error)
- **Description**: Fallback state when OCR scans an image or document but identifies no valid event dates or timestamps. Offers hints (glare reduction, better lighting), manual crop tool, or fallback manual event creation.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_87}}` (*Source Chooser*) — retry scan with a different source or photo.
  - `{{DATA:SCREEN:SCREEN_76}}` (*Edit Event / Manual Create*) — proceed with manual entry using extracted image text.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_56}}` (*Scan Processing Progress*)

### Calendar Permission Denied
- **Screen ID**: `{{DATA:SCREEN:SCREEN_42}}`
- **Shell**: `{{DATA:SHELL:SHELL_43}}` (Stack Navigation / Permission)
- **Description**: Informative system barrier screen when iOS Calendar access is toggled off. Explains why Pencil'd requires write access to write events without manual copying, accompanied by a direct "Open iOS Settings" deep link.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_34}}` (*Default Calendar*) — re-attempt connection once granted.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_85}}` (*Event Review & Edit*) or `{{DATA:SCREEN:SCREEN_34}}` (*Default Calendar*)

### Notification Permission Denied
- **Screen ID**: `{{DATA:SCREEN:SCREEN_40}}`
- **Shell**: `{{DATA:SHELL:SHELL_41}}` (Stack Navigation / Permission)
- **Description**: Informative barrier screen when iOS Push Notifications are disabled. Explains the impact on departure alarms and conflict alerts, with a one-tap deep link to iOS Notification Settings.
- **Sub-Screens & Connected Destinations**:
  - `{{DATA:SCREEN:SCREEN_28}}` (*Notification Preferences*) — return to preferences after enabling.
- **Parent Screen**:
  - `{{DATA:SCREEN:SCREEN_28}}` (*Notification Preferences*) or `{{DATA:SCREEN:SCREEN_83}}` (*Reminder Schedule Editor*)

---

## Supplementary Desktop Marketing Assets

### Marketing Copy & Email Template
- **Screen ID**: `{{DATA:SCREEN:SCREEN_3}}`
- **Device**: DESKTOP
- **Description**: Comprehensive launch marketing presentation and HTML email template embedding the Pencil'd 3D icon banner, value proposition headlines, feature highlight pills, social media copy packs, and search ad headlines.
- **Parent Screen**: Standalone promotional collateral.
