# App Review Notes & Submissions Guidance

Provide this exact information in App Store Connect under **App Review Information > Notes** to ensure smooth approval across photo access, calendar integration, and subscription review.

---

## App Review Notes Text

```text
Dear Apple App Review Team,

Pencild is a privacy-first utility that processes screenshots and event flyers on-device using Apple's Vision and NaturalLanguage frameworks to create Apple Calendar events and Reminders.

1. PERMISSIONS RATIONALE:
- Photo Library (Read): Used exclusively to let users select event flyers or detect screenshots in their Screenshots album. Vision OCR and text extraction run locally. Pencild does not upload images, OCR strings, or photo metadata.
- Calendars & Reminders (Full Access): Used exclusively to write and sync the extracted events and staggered alert reminders into the user's native Apple Calendar and Reminders apps upon explicit user confirmation.

2. ON-DEVICE PRIVACY VERIFICATION:
The core flyer analysis, date inference, Calendar, and Reminders workflow can be tested with Airplane Mode enabled. StoreKit purchases and user-initiated links to policies, Apple Maps, or event websites require the corresponding Apple or web service.

3. DEMO ASSETS & WALKTHROUGH:
- To test the extraction engine immediately without granting photo library access, tap "Try sample flyer" on the Home tab.
- To test with your own images, save a concert flyer, conference ticket, or wedding invitation to Photos on the review device, then tap "Recent screenshots" or "Photo library" on the Home tab.

4. IN-APP PURCHASES & SUBSCRIPTIONS:
- Free plan: 10 scans per month (only scans that find a new event count) and 1 alert per event. There is no history limit.
- Auto-renewable subscriptions in the "Pencil’d Memberships" group. Each has a 1-week free trial for eligible users:
  * Pencil’d Plus (Monthly & Annual): unlimited scans, up to 3 alerts per event, automatic detection of new event screenshots, and highlighting of screenshots that look like events.
  * Pencil’d Premium (Monthly & Annual): everything in Plus, plus PDF and file import (every page), work schedules and multi-date flyers as separate events, tailored alert plans and RSVP-deadline reminders, and grouping of likely duplicates.
- Lifetime (non-consumable, one-time purchase): Pencil’d Plus Lifetime and Pencil’d Premium Lifetime unlock the same features permanently. They are an introductory offer shown through April 13, 2027.
- Paid features stay visible on every plan. Tapping one without the plan opens the Plus or Premium paywall instead of running it.
- Restore Purchases, the privacy policy, and the terms of use are available in each paywall and in the Settings tab.

5. REVIEWER CONTACT:
If you encounter any questions or require additional details during review, please reach out via phone or email directly.
```

---

## Required App Store Metadata Fields

| Field | Value / Guidance |
|---|---|
| **App Name** | Pencil’d: Photo to Calendar *(27/30)* |
| **Subtitle** | Flyers & screenshots to events *(30/30)* |
| **Keywords** | `picture,image,scan,work,schedule,shift,invite,ticket,pdf,import,file,reminder,date,party,camera` *(95/100; singular, no spaces, no words repeated from name or subtitle)* |
| **Promotional Text** | Turn flyers, work schedules, invites, photos, and screenshots into calendar events and reminders. Snap or import on your iPhone, approve, and Pencil’d does the rest. *(165/170)* |
| **Primary Category** | Productivity |
| **Secondary Category** | Utilities |
| **Content Rights** | Contains no third-party content requiring explicit license. |
| **Age Rating** | 4+ (No unrestricted web access, no user-generated content). |
| **Data Nutrition Label** | "Data Not Collected" across all data categories. |
| **Privacy Policy URL** | `https://getpencild.com/privacy` *(Must be live and valid)* |
| **Support URL** | `https://getpencild.com/support` *(Must be live and valid)* |
| **Marketing URL** | `https://getpencild.com` |
| **Copyright** | `2026 LiminalForge, LLC` (matches `NSHumanReadableCopyright` in `Info.plist`) |
| **Seller** | LiminalForge, LLC: requires Apple Developer Program enrollment as an organization (D-U-N-S number) |

> **Listing rationale (2026-10-13):** "photo to calendar" is a standalone App Store
> autocomplete term, while "screenshot to calendar" only appears inside other apps'
> names. The name takes the most-searched phrase; the subtitle and keywords cover the
> other phrasings ("screenshot", "flyer", "event", "scan", "picture", "image",
> "pdf"), which Apple likely combines across fields. "work" + "schedule" target the
> heavily searched "work schedule" terms. Work schedules and multi-date flyers are
> read as one event per shift or date (Premium; lower plans see the paywall).
> Productivity is the accurate primary category and the one most direct competitors use; Apple counts the
> primary category as a search match. Name, subtitle, and keywords change only with a
> new version; promotional text can change anytime.
