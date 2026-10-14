# TestFlight QA Verification Plan

This checklist outlines the manual and automated validation procedures for TestFlight builds of Pencil'd on physical iPhone hardware. The app supports iOS 17.0 and later (`deploymentTarget` in `project.yml`), so test on the current iOS release and on iOS 17.

---

## Matrix of Test Cases

### 1. Fresh Install & Permission Prompts
- [ ] **Clean Install:** Launch app on fresh device. Verify `AppState` initializes cleanly without corrupted state.
- [ ] **Photo Library Authorization:**
  - Select "Scan Recent Screenshots" or "Choose from Photo Library".
  - Verify native system modal displays custom description: *"Pencild analyzes screenshots and event flyers directly on your iPhone..."*.
  - Test "Limited Access": Select 2 screenshots. Confirm app processes only selected assets without crashing.
  - Test "Deny Access": Confirm the app shows the **Allow Photo Access** guidance, offers **Open Settings**, and still allows **Choose a Photo Instead** through the system picker without freezing.
- [ ] **Apple Calendar Authorization:**
  - Save an extracted candidate to Calendar.
  - Verify system modal requests full access with custom description: *"Pencild requires full calendar access to schedule extracted events..."*.
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
- [ ] **Product Loading:** Open `PlusPaywallView` and `PremiumPaywallView`. Verify the prices come from the Sandbox storefront and match App Store Connect. US prices: Plus $3.99/mo, $24.99/yr, $39.99 lifetime; Premium $6.99/mo, $39.99/yr, $79.99 lifetime. Annual is selected by default.
- [ ] **Lifetime Offer Window:** Verify the Lifetime option and its end date ("Pay once · offer ends Apr 13, 2027") show on both paywalls, and that Manage Plan shows lifetime owners "Lifetime access".
- [ ] **Free Trial Purchase:** On the Plus paywall with Annual or Monthly selected, tap the trial button (e.g. "Start 1-Week Free Trial" for an eligible account). Verify the Apple StoreKit confirmation sheet displays correctly.
- [ ] **Entitlement Activation:** Complete purchase. Verify the plan unlocks immediately: Plus shows auto-detection; Premium also allows PDF import and work schedules.
- [ ] **Lifetime Purchase:** Buy each lifetime product on a fresh sandbox account. Verify the matching tier unlocks and nothing renews.
- [ ] **Restore Purchases:** Reinstall app or launch on secondary sandbox device. Tap "Restore Purchases" in a paywall or Manage Plan and confirm the subscription or lifetime purchase is detected via `Transaction.currentEntitlements`.
- [ ] **Cancellation / Expiration:** In App Store Sandbox settings, accelerate subscription renewal to trigger expiration. Confirm app gracefully downgrades to `Starter` tier.

### 4. Free Plan Limits & Paywall-on-Attempt
- [ ] **Scan Allowance:** On the free plan, Home shows "N of 10 free scans left this month". Rescanning a flyer that was already found does not use a scan. After 10 scans that found new events, the next scan opens the Plus paywall without scanning.
- [ ] **Batch Allowance:** With fewer free scans left than selected screenshots, the app asks to deselect, upgrade, or discard before scanning. Nothing is skipped silently.
- [ ] **Alerts:** On the free plan an event keeps 1 alert; adding another opens the paywall. Plus and Premium allow 3.
- [ ] **Locked Controls Stay Visible:** On the free plan, PDF/file import, tailored alerts, RSVP-deadline reminders, and the duplicates filter are visible. Tapping each opens the matching paywall. No suggested alert plan or deadline date is revealed.
- [ ] **Work Schedules (Premium):** Scan a screenshot of a work schedule on Free or Plus. Verify the Premium paywall opens and no events are created. On Premium, verify each shift becomes its own event and they open together in Batch Review.

### 5. On-Device Processing & Offline Assurance
- [ ] **Airplane Mode Scan:** Enable Airplane Mode (Wi-Fi and Cellular OFF).
- [ ] Perform full workflow: Screenshot OCR -> Date Extraction -> Calendar Sync -> Reminder Creation.
- [ ] Confirm the core scan, extraction, Calendar, and Reminders workflow succeeds without network connectivity. User-opened web/Maps links and StoreKit storefront operations are out of scope for this offline assertion.

---

## Definition of Release Candidate (Gate Checklist)

A build qualifies for App Store submission **ONLY IF**:
1. All Critical and High test cases pass on physical iPhone hardware running the current iOS release.
2. A smoke pass on iOS 17 (physical device or iOS 17 simulator runtime) passes: launch, sample flyer scan, Photo library scan, review and save to Calendar, one paywall purchase, and Restore Purchases. Apple Intelligence features are unavailable there, so the rules-based extraction path must work on its own.
3. Crash-free user sessions reach 100% in internal TestFlight testing.
4. No memory leaks detected in Instruments during repeated Vision OCR cycles.
5. No app-originated telemetry or product-data upload is observed via Instruments or a configured proxy. Record StoreKit/App Store system traffic and user-initiated web/Maps links separately rather than treating them as product-data uploads.

## Evidence Record

Record the exact candidate for every QA pass:

- Git SHA:
- Marketing version / build:
- TestFlight build ID:
- Device model / OS:
- Tester / date:
- Automated-test result bundle:
- Defects or accepted exceptions:

## Live Apple Intelligence Gate

Before promoting a TestFlight release candidate, run the compatible-device lane
in `docs/runbooks/LIVE-AI-EVALUATION.md` and retain its `.xcresult` with the release
evidence. This is separate from the default hermetic unit-test suite.
