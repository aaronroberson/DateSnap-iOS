# Pencil’d Stitch Screen Prompt Pack

Use this as a single copy-paste prompt in Google Stitch to regenerate the Pencil’d mobile UI set.

## Master instruction

Design a complete iPhone-native mobile UI system for a rebranded iOS productivity app named **Pencil’d**.

Brand:
- App name: Pencil’d
- Slogan: “Scanned. Reviewed. Pencil’d.”

Product purpose:
Pencil’d turns screenshots, flyers, tickets, images, PDFs, and multi-page documents into reviewed calendar events and reminders.

Core workflow:
1. Scan or import a screenshot, flyer, ticket, image, or PDF
2. Extract likely event details
3. Let the user review and edit the event
4. Save it to calendar
5. Optionally schedule reminders

## Visual direction

Base the aesthetic on the attached Pencil’d logos and icon concepts:
- deep indigo / midnight navy backgrounds
- warm off-white card surfaces
- Pencil’d gradient accents using orange → coral → magenta
- subtle violet edge-lighting
- rounded-square calendar / pencil “P” brand motif

The screens should feel:
- less busy than the logo art
- more spacious than the current DateSnap screens
- polished, premium, calm, and Apple-native
- visually consistent across all screens
- legible and trust-building rather than flashy

Avoid:
- sparkles
- orbit rings
- rainbow trails
- heavy background grids
- neon outline typography
- cluttered decorative effects
- duplicated actions or repeated identical links on the same screen

Use:
- large elegant corner radii
- subtle shadows
- restrained glassmorphism only where useful
- strong typography hierarchy
- generous spacing
- one strong primary action per screen
- at most one secondary action and one tertiary text action where needed

## Content and UX rules

- Use **Pencil’d** everywhere, never DateSnap
- Keep copy concise and realistic
- No more than one instance of the same link/action label on a single screen
- Do not repeat Restore, Try Again, Not Now, Privacy, or Terms multiple times in one screen
- The UI should account for both current visible screens and additional functionality represented in code/planning but not yet visually represented
- Every screen should feel production-ready for an App Store launch design system

## Screen set

Create the following iPhone screens in one unified design system.

### 01. Home Empty State
Design the first-run home screen before any event has been scanned or saved.

Include:
- Pencil’d brand presence near the top
- Headline: “Scan it. Review it. Pencil’d.”
- Supporting copy explaining that screenshots, flyers, tickets, images, and PDFs can become calendar events and reminders
- Primary CTA: “Scan screenshot or flyer”
- Secondary CTA: “Import PDF or file”
- Tertiary lightweight action: “Try sample”
- Small supported-source preview row: Screenshots, Photos, PDFs, Tickets
- Subtle preview area hinting at smart suggestions from recent screenshots

Style notes:
- premium onboarding feel
- very spacious
- strong hierarchy
- calm dark background with warm surfaces

### 02. Source Chooser
Design a source selection screen titled “Add an event.”

Include four large source tiles:
- Recent screenshots
- Photo library
- PDF or file import
- Try sample flyer

Each tile should have:
- a simple icon
- one line of supporting copy

Include:
- one short trust note about review before saving

Style notes:
- simple, beautiful, spacious source cards
- no clutter

### 03. Recent Screenshot Triage
Design a smart shortlist screen for likely event screenshots from the user’s library.

Include:
- Title: “Recent screenshots”
- Section label: “Likely event screenshots”
- Thumbnail cards or a clean grid
- Confidence chips like “Has date,” “Has time,” “High match”
- One primary action per item: “Review scan”
- One footer action: “Browse all photos”

Style notes:
- premium quiet intelligence
- should feel helpful, not invasive

### 04. File Import
Design a PDF and file import screen for Premium-style workflows.

Include:
- Title: “Import file”
- Selected file card with filename, file type, and page count
- Page preview strip
- Extraction mode options:
  - Scan first page
  - Scan all pages
  - Find all event dates
- Short note about agendas, itineraries, school schedules, and tickets
- Primary CTA: “Process file”

Style notes:
- clean productivity UI
- elegant and document-centric

### 05. Processing State
Design a scan/extraction progress screen.

Include:
- Title: “Reading your event”
- Branded progress visualization
- Source thumbnail preview
- Step list:
  - Detecting text
  - Finding dates and times
  - Building event details
  - Preparing review
- Optional short note about on-device processing

Style notes:
- reassuring
- premium
- strong focal center
- lots of whitespace

### 06. Event Review and Edit
Design the core trust screen where users verify extracted event details before saving.

Include:
- Top title: “Review event”
- Source preview thumbnail
- Editable fields:
  - Event title
  - Date
  - Start time
  - End time
  - Location
  - Notes
- A subtle extraction confidence or quality indicator
- A compact “Detected from scan” section
- A visible date-format ambiguity suggestion when relevant
- Primary CTA: “Save to Calendar”
- Secondary action: “Set reminders”
- Optional text action: “See scan details”

Add advanced functionality representation:
- alternate interpretations / date candidates
- extracted text evidence
- support for screenshot, photo, PDF, and multi-page sources

Style notes:
- this is the most important product screen
- must feel trustworthy, calm, premium, and spacious

### 07. Extraction Details
Design a trust/explanation screen titled “Scan details.”

Include:
- Extracted text snippets
- Primary interpreted event summary
- Alternative interpretation cards
- Confidence labels
- One action to apply another interpretation
- Small note explaining that Pencil’d asks for review before saving

Style notes:
- editorial, clear, understandable
- should not feel technical or developer-heavy

### 08. Reminder Schedule Editor
Design a reminder configuration screen titled “Reminders.”

Include:
- Event summary pill at top
- Preset reminder chips:
  - Day before
  - Morning of
  - 1 hour before
- Custom reminder date/time builder
- Toggle for multiple reminders
- Smart suggestion chips by event type: Travel, Concert, Appointment, School
- Optional reminder template presets
- Primary CTA: “Save reminders”

Style notes:
- soft dark editor
- warm controls
- uncluttered

### 09. Saved Event Detail
Design the event detail screen after a successful save.

Include:
- Event title header and saved state
- Event summary card with title, date, time, venue, source type, and notes preview
- Visible confirmation that it was added to calendar
- Reminder summary section
- Actions:
  - View in Calendar
  - Edit reminders
  - Archive scan
- Original source badge: Screenshot, Flyer, PDF, or Batch import
- One section explaining why Pencil’d chose the date/time
- Processing status chips like Saved, Reviewed, Reminder set

Style notes:
- elegant detail hierarchy
- less dense than a standard settings screen

### 10. History and Archive
Design a full History screen.

Include:
- Top title: “History”
- Segmented control: Recent, Saved, Archived
- Search field
- Filter chips: Flyers, Screenshots, PDFs, Tickets
- Item list with thumbnail, event title, extracted date, source type, and status badge
- Overflow or swipe affordance for archive / restore / delete
- One CTA for “Scan new”
- A compact area that hints at “Why this date?” or “Processing log” for one item

Style notes:
- airy dark list
- strong organization
- clean archive patterns

### 11. Smart Suggestions
Design a screen titled “Suggested events.”

Purpose:
represent smart event discovery from recent screenshots and photos.

Include:
- Intro copy explaining these were found in recent screenshots/photos
- Suggestion cards with thumbnail, probable event title, date guess, and confidence
- Actions: Review, Dismiss, Save for later
- Small trust note about private on-device analysis

Style notes:
- intelligent but gentle
- should feel useful, not invasive

### 12. Batch Scan Queue
Design a power-user queue screen titled “Batch scan.”

Include:
- Queue list with thumbnails, filenames/source labels, and processing states
- Status chips: Waiting, Processing, Needs review, Saved
- Summary bar with total items and extracted events
- Primary CTA: “Process all”
- Secondary action: “Review individually”

Style notes:
- elegant operations screen
- sparse and premium
- not technical-looking

### 13. Calendar Permission Denied
Design a graceful permission-denied screen.

Include:
- Pencil’d illustration using calendar + lock cue
- Title: “Calendar access is off”
- Brief explanation of why calendar permission helps
- Primary CTA: “Open Settings”
- Secondary action: “Not now”
- Small reassurance about user control and privacy
- Optional note about what still works without calendar access

Style notes:
- calm and trust-building
- no harsh warning colors

### 14. Notification Permission Denied
Design a graceful reminders-permission screen.

Include:
- branded bell/reminder illustration
- Title: “Reminders are turned off”
- Short explanation connecting notifications to event follow-up
- Primary CTA: “Enable in Settings”
- Secondary action: “Skip for now”
- Optional preview of reminder types
- Small privacy/control reassurance

Style notes:
- soft, clear, helpful

### 15. Plus Paywall
Design the Pencil’d Plus Paywall screen.

Purpose:
main subscription tier for most individual users.

Include:
- Close button on left
- One Restore action on right
- Headline: “Never miss the date again.”
- Subheadline describing Plus as ideal for everyday scanning, reminders, and calendar saving
- Clean Pencil’d hero composition using screenshot/flyer/calendar cues
- Feature cards:
  1. Unlimited screenshot and flyer scans
  2. Smart review before saving
  3. Multi-reminder scheduling
  4. Apple Calendar sync
  5. Extended history access
- Monthly and annual pricing options
- Annual visually recommended
- One concise savings badge
- One primary CTA
- One short trust note
- One legal row only: Restore, Terms, Privacy

Style notes:
- approachable but premium
- cleaner and more spacious than the old DateSnap Plus screen

### 16. Premium Paywall
Design the Pencil’d Premium Paywall screen.

Purpose:
flagship tier for document-heavy and higher-volume workflows.

Include:
- Close button on left
- One Restore action on right
- Compact Pencil’d brand pill near top
- Headline: “Turn screenshots and files into plans.”
- Subheadline about PDFs, multi-page schedules, batch imports, and advanced controls
- Minimal premium hero visual using file/calendar/Pencil’d icon cues
- Feature cards:
  1. Everything in Plus
  2. PDF & Files import
  3. Multi-page schedule extraction
  4. Batch scanning
  5. Advanced reminder and calendar controls
- Pricing options:
  - Annual plan selected by default
  - Monthly option
  - Optional quieter lifetime option
- One value badge such as “Best value” or “Most popular”
- One primary CTA
- One trust note
- One legal/footer row only: Restore, Terms, Privacy

Style notes:
- dark luxury productivity UI
- fewer cards, more breathing room, higher perceived value

### 17. Settings and Permissions Hub
Design a Settings screen for Pencil’d.

Include:
- Subscription/account summary card
- Permissions section:
  - Photos
  - Calendar
  - Notifications
- Defaults section:
  - Default calendar
  - Reminder presets
  - Source preferences
- Premium section:
  - Manage plan
  - Restore purchases
- Privacy section:
  - On-device processing
  - Data collection stance

Style notes:
- refined grouped-list iOS settings style
- warm and premium, not generic

## Final output goals

- Keep every screen visually unified
- Keep layouts more spacious and premium than the original DateSnap Stitch screens
- Preserve strong product truth and realistic workflows
- Represent existing visible screens plus additional missing surfaces implied by the current code/planning
- Avoid duplicated links and duplicate CTA labels on individual views
- Make the whole system feel launch-ready for a polished iOS product brand refresh under Pencil’d
