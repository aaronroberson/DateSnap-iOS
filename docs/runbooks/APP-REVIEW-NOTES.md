# App Review Notes & Submissions Guidance

Provide this exact information in App Store Connect under **App Review Information > Notes** to ensure smooth approval across photo access, calendar integration, and subscription review.

---

## App Review Notes Text

```text
Dear Apple App Review Team,

DateSnap is a privacy-first utility that processes screenshots and event flyers 100% on-device using Apple's Vision and NaturalLanguage frameworks to create Apple Calendar events and Reminders.

1. PERMISSIONS RATIONALE:
- Photo Library (Read): Used exclusively to let users select event flyers or detect screenshots in their Screenshots album. All Vision OCR and text extraction runs locally on the Neural Engine. Zero images, OCR strings, or metadata leave the device.
- Calendars & Reminders (Full Access): Used exclusively to write and sync the extracted events and staggered alert reminders into the user's native Apple Calendar and Reminders apps upon explicit user confirmation.

2. ON-DEVICE PRIVACY VERIFICATION:
DateSnap operates with an air-gapped architecture. You can test all features—including flyer analysis, date inference, and calendar creation—with Airplane Mode enabled (Wi-Fi and Cellular data turned off).

3. DEMO ASSETS & WALKTHROUGH:
- To test the extraction engine immediately without granting camera roll access, tap "Try Sample Flyer" on the Home tab.
- To test with sample images, you can save any concert flyer, conference ticket, or wedding invitation into the Photos app on the review device and tap "Scan Recent Screenshots" or "Choose from Photo Library".

4. IN-APP PURCHASES & SUBSCRIPTIONS:
- DateSnap includes auto-renewable subscriptions in the "DateSnap Memberships" group:
  * DateSnap Plus (Monthly & Annual): Unlocks automated screenshot scanning. Includes a 7-day free trial.
  * DateSnap Premium (Monthly & Annual): Unlocks full automation, document import, and unlimited archive triage.
- Subscription terms, privacy policy, and terms of use are accessible directly in the paywall footer and in the Settings tab.

5. REVIEWER CONTACT:
If you encounter any questions or require additional details during review, please reach out via phone or email directly.
```

---

## Required App Store Metadata Fields

| Field | Value / Guidance |
|---|---|
| **App Name** | DateSnap: Screenshot to Calendar |
| **Subtitle** | On-Device Flyer & Event Sync |
| **Primary Category** | Utilities |
| **Secondary Category** | Productivity |
| **Content Rights** | Contains no third-party content requiring explicit license. |
| **Age Rating** | 4+ (No unrestricted web access, no user-generated content). |
| **Data Nutrition Label** | "Data Not Collected" across all data categories. |
| **Privacy Policy URL** | `https://datesnap.app/privacy` *(Must be live and valid)* |
| **Support URL** | `https://datesnap.app/support` *(Must be live and valid)* |
| **Marketing URL** | `https://datesnap.app` |
