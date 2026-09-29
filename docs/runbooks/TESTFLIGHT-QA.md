# TestFlight QA Verification Plan

This checklist outlines the manual and automated validation procedures for TestFlight builds of DateSnap on physical iOS 18+ hardware.

---

## Matrix of Test Cases

### 1. Fresh Install & Permission Prompts
- [ ] **Clean Install:** Launch app on fresh device. Verify `AppState` initializes cleanly without corrupted state.
- [ ] **Photo Library Authorization:**
  - Select "Scan Recent Screenshots" or "Choose from Photo Library".
  - Verify native system modal displays custom description: *"DateSnap analyzes screenshots and event flyers directly on your iPhone..."*.
  - Test "Limited Access": Select 2 screenshots. Confirm app processes only selected assets without crashing.
  - Test "Deny Access": Confirm app redirects cleanly to `CalendarPermissionDeniedView` or custom in-app guidance without freezing.
- [ ] **Apple Calendar Authorization:**
  - Save an extracted candidate to Calendar.
  - Verify system modal requests full access with custom description: *"DateSnap requires full calendar access to schedule extracted events..."*.
  - Verify event is inserted into the user's default calendar with correct title, start time, end time, and alarm offsets.
- [ ] **Apple Reminders Authorization:**
  - Toggle reminder alert schedule.
  - Verify system modal requests reminders access.
  - Confirm reminder is created in the user's default reminder list with staggered alerts (-86400s, -7200s).
- [ ] **Local Push Notifications:**
  - Verify prompt appears upon first schedule request.
  - Schedule an event 5 minutes into the future. Lock device and confirm notification banner triggers with audio and custom action *"View Event Details"*.
  - Tap notification banner and verify deep-link navigation loads the event in `SavedEventDetailView`.

### 2. On-Device OCR & Temporal Inference Engine
- [ ] **Concert Flyer Test:** Scan an image with dense graphics and artistic fonts. Confirm title, venue, and date are extracted with High or Medium confidence badge.
- [ ] **Ambiguous Date Test:** Scan an invitation with date `04/05/2026`. Verify Ambiguous Date glass banner renders, and tapping the swap button toggles between April 5 and May 4.
- [ ] **Door vs Show Time Test:** Scan ticket specifying "Doors 7:00 PM / Show 8:00 PM". Verify start time defaults to 8:00 PM and notes record door time.
- [ ] **No Dates Found:** Scan a screenshot of plain landscape or receipt without dates. Verify `NoDatesFoundView` renders with recovery actions.

### 3. StoreKit 2 & Paywall Flows
- [ ] **StoreKit Sandbox Account:** Log into Settings > Developer > Sandbox Apple Account.
- [ ] **Product Loading:** Open `PlusPaywallView` and `PremiumPaywallView`. Verify prices reflect the Sandbox storefront ($4.99/mo, $39.99/yr, $8.99/mo, $69.99/yr).
- [ ] **Free Trial Purchase:** Tap "Start 7-Day Free Trial" on Plus plan. Verify Apple StoreKit confirmation sheet displays correctly.
- [ ] **Entitlement Activation:** Complete purchase. Verify app state immediately unlocks Plus badge and auto-detection features.
- [ ] **Restore Purchases:** Reinstall app or launch on secondary sandbox device. Tap "Restore" and confirm active subscription is detected via `Transaction.currentEntitlements`.
- [ ] **Cancellation / Expiration:** In App Store Sandbox settings, accelerate subscription renewal to trigger expiration. Confirm app gracefully downgrades to `Starter` tier.

### 4. Zero-Cloud & Offline Assurance
- [ ] **Airplane Mode Scan:** Enable Airplane Mode (Wi-Fi and Cellular OFF).
- [ ] Perform full workflow: Screenshot OCR -> Date Extraction -> Calendar Sync -> Reminder Creation.
- [ ] Confirm 100% functionality with zero network connectivity.

---

## Definition of Release Candidate (Gate Checklist)

A build qualifies for App Store submission **ONLY IF**:
1. All Critical and High test cases pass on physical iPhone hardware running iOS 18.
2. Crash-free user sessions reach 100% in internal TestFlight testing.
3. No memory leaks detected in Instruments during repeated Vision OCR cycles.
4. Zero network requests confirmed via Charles Proxy / Proxyman / Instruments.
