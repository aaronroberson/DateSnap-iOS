# DateSnap: Feature-Complete Product Engineering Plan & Runtime Audit

**Date:** 2026-09-29  
**Status:** Approved for Implementation  
**Scope:** Core Feature Completeness, Runtime Wiring, and Prototype-to-Product Transition (Excludes Wave 2 App Store packaging/signing)

---

## 1. Executive Summary

DateSnap possesses an advanced on-device algorithmic foundation: a spatial Vision OCR engine (`OCRService.swift`), a multi-detector chronological inference pipeline (`EventExtractionService.swift`), SwiftData entity models (`SwiftDataEntities.swift`), and protocol-driven EventKit, PhotoKit, UserNotifications, and StoreKit 2 services.

However, from an end-to-end product and runtime perspective, **the app is currently operating as a disconnected prototype**. The polished SwiftUI views (`HomeEmptyStateView.swift`, `EventReviewEditView.swift`, `PlusPaywallView.swift`, `HistoryArchiveView.swift`) are almost entirely unwired from the underlying production services. User interactions rely on hardcoded `Task.sleep` simulations, mutating in-memory volatile arrays in `AppState.swift`, and cycling through pre-baked mock flyer objects (`sampleNeonSunset`, `sampleDentalCheckup`).

### The Three Fundamental Product Gaps:
1. **Orphaned Service & ViewModel Layer:** `ScanViewModel`, `HomeViewModel`, and `EventReviewViewModel` contain full production logic for scanning, OCR, calendar/reminder creation, and SwiftData persistence, but **zero views in the app instantiate or call them**.
2. **Cold-Launch Amnesia:** SwiftData container initialization in `DateSnap.swift` is never queried by the UI. `HistoryArchiveView.swift` displays only in-memory mock events from `AppState.events`, wiping all user-saved events on app relaunch.
3. **Simulated Paywalls & Feature Gating:** Subscriptions in `PlusPaywallView.swift` and `PremiumPaywallView.swift` simulate purchases with dummy 1-second timers and set local booleans, completely disconnected from `SubscriptionService.swift`. The premium features promised in copy (document/PDF import, automatic background photo scanning) do not exist in code.

---

## 2. Feature Inventory

| Feature | Intended Product Behavior | Evidence in Repo | Status | User Impact | Priority |
|---|---|---|---|---|---|
| **Screenshot Auto-Scan** | Ingest recent screenshots from smart album on launch or tap. | `PhotoLibraryService.swift:44`, `HomeViewModel.swift:92`, `HomeEmptyStateView.swift:248` | **Mock** | User taps "Scan Recent Screenshots", sees a fake 600ms delay, and always receives hardcoded `sampleNeonSunset`. Real photos are never fetched. | **P0** |
| **Photo Library Picker** | Open native system photo picker (`PhotosPicker`) to choose any flyer/image. | `HomeEmptyStateView.swift:270` | **Missing** | Button only shows toast `"Opening Photo Library picker..."` and presents `sampleDentalCheckup`. `PhotosPicker` is absent. | **P0** |
| **Try Sample Flyer** | Run real OCR and inference pipeline on a bundled sample image to demonstrate zero-permission parsing. | `HomeEmptyStateView.swift:353` | **Mock** | Toggles a static disclosure card with hardcoded strings. Does not run OCR or launch the review flow. | **P1** |
| **On-Device Vision OCR** | Recognize text blocks and spatial line geometry locally off main thread. | `OCRService.swift:78` | **Implemented (Unwired)** | Production-ready with layout bounding boxes and floor filtering, but unwired to the UI. | **P0** |
| **Date/Time Inference** | Multi-pattern extraction of title, dates, windows, venues, timezone. | `EventExtractionService.swift:513` | **Implemented (Unwired)** | Production-ready inference engine, but never fed live OCR results from user input. | **P0** |
| **Doors vs Show Time** | Select show time as start time; store door time in notes. | `EventExtractionService.swift:894` | **Partial** | Parses `isShow` flag into tuple, but sort logic chooses earliest (doors) as start time. Door time is dropped. | **P1** |
| **Ambiguous Date Swap** | Detect `DD/MM` vs `MM/DD` ambiguity and offer 1-tap swap in review UI. | `EventExtractionService.swift:650`, `EventReviewEditView.swift:108` | **Partial** | Detection logic and UI card exist, but swapping is not bound to a live view model or persisted entity. | **P0** |
| **Calendar Event Commit** | Write reviewed event to Apple Calendar with alarms upon explicit save. | `CalendarService.swift:57`, `EventReviewEditView.swift:544` | **Mock** | Button sleeps 700ms and updates `appState.events`. `EKEventStore` is never invoked from UI. | **P0** |
| **Reminders Commit** | Write reminders with staggered offsets to Apple Reminders upon explicit save. | `ReminderService.swift:69`, `EventReviewEditView.swift:544` | **Mock** | `EKEventStore` reminders API is never called from `EventReviewEditView` or `ReminderScheduleEditorView`. | **P0** |
| **Local Notification Alerts** | Schedule UNNotificationRequest for pre-event alerts with deep-links. | `NotificationService.swift:74` | **Partial** | Scheduling code works, but notification deep-link `DateSnapDeepLinkEvent` has no listener in `AppState`. | **P1** |
| **Persistent History & Triage** | Retain saved events in SwiftData; support search, filter, and triage across launches. | `SwiftDataEntities.swift:131`, `HistoryArchiveView.swift:9` | **Mock** | `HistoryArchiveView` reads volatile `appState.events`. Cold launch wipes history and reverts to sample events. | **P0** |
| **StoreKit 2 Subscriptions** | Purchase Plus/Premium, restore transactions, listen to status updates. | `SubscriptionService.swift:42`, `PlusPaywallView.swift:242` | **Mock** | Paywalls use dummy `Task.sleep` and toggle mock booleans. Real StoreKit 2 calls are bypassed. | **P0** |
| **Files & PDF Import (Premium)** | Import multi-page event PDFs and flyers from iOS Files / iCloud Drive. | `PremiumPaywallView.swift:60`, `ManagePlanView.swift:170` | **Missing** | Heavily advertised in UI copy and paywalls, but zero code exists for `UIDocumentPicker` or `PDFKit`. | **P1** |
| **System Settings Deep-Links** | Redirect user to iOS Settings when permissions are denied. | `CalendarPermissionDeniedView.swift:189`, `NotificationPermissionDeniedView.swift:161` | **Mock** | Buttons display a toast `"Opening iOS Settings..."` instead of invoking `UIApplication.openSettingsURLString`. | **P1** |

---

## 3. Core Flow Audit

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 CORE USER JOURNEY                                       │
│                                                                                        │
│  [Home Entry] ──> [Ingestion] ──> [Vision OCR] ──> [Inference] ──> [Review / Edit]     │
│       │                 │               │                │                 │           │
│    MOCKED            MISSING        UNWIRED          UNWIRED            MOCKED         │
│  (Fake delays)    (No Picker)    (Never called)   (Doors bug)       (Fake Save)        │
│                                                                            │           │
│                                                                            ▼           │
│  [Local Alerts] <── [Reminders] <── [Calendar] <── [History/Store] <───────┘           │
│         │                 │              │                │                            │
│     NO LISTENER        MOCKED         MOCKED          MOCKED                           │
│   (Unwired deep)   (Never called) (Never called)   (In-memory only)                    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Flow 1: Home Entry Points & Ingestion
- **Current Breakdown:** In `HomeEmptyStateView.swift:248-280`, tapping "Scan Recent Screenshots" sets `isScanning = true`, sleeps 600ms, sets `isScanning = false`, and assigns `appState.activeModal = .eventReviewEdit(DateSnapEvent.sampleNeonSunset)`. Tapping "Choose from Photo Library" sets `activeModal = .eventReviewEdit(DateSnapEvent.sampleDentalCheckup)`.
- **Failure:** The user never actually chooses an image, nor are recent screenshots retrieved from the photo library.

### Flow 2: OCR Extraction & Temporal Inference
- **Current Breakdown:** `ScanViewModel.swift:70-147` orchestrates `ocrService.recognizeLines(in:image)` and `extractionService.extractCandidates(from:ocrResult)`. 
- **Failure:** Because `ScanViewModel` is never instantiated by `HomeEmptyStateView`, real OCR and extraction are completely dead code at runtime.

### Flow 3: Candidate Review, Ambiguity Resolution & Editing
- **Current Breakdown:** `EventReviewEditView.swift:24-35` initializes its form from the passed `DateSnapEvent`. It contains UI for editing dates, time windows, and locations.
- **Failure:** It does not use `EventReviewViewModel`. The ambiguous date banner toggles internal `@State` variables without recalculating parsed `Date` components or updating calendar targets.

### Flow 4: Save to Calendar & Reminders
- **Current Breakdown:** In `EventReviewEditView.swift:544-560`, tapping "Save Event to Calendar" triggers a 700ms sleep, sets `showSuccessToast = true`, calls `appState.saveEvent(updated)`, sleeps 1200ms, and dismisses.
- **Failure:** `CalendarService.createEvent` and `ReminderService.createReminder` are never called. Nothing is written to the user's iOS Calendar or Reminders apps.

### Flow 5: Notification Scheduling & Deep-Linking
- **Current Breakdown:** `NotificationService.swift:143-156` catches notification taps and posts `NSNotification.Name("DateSnapDeepLinkEvent")`.
- **Failure:** `AppState` and `ContentView` have no subscriber for this notification. Tapping an alert launches the app to the default tab without opening the saved event detail.

### Flow 6: History & Archive Persistence
- **Current Breakdown:** `HistoryArchiveView.swift:9-21` filters `appState.events`. 
- **Failure:** SwiftData's `ModelContext` is ignored. Force-quitting the app clears all user modifications, restoring the 3 hardcoded sample events on next launch.

### Flow 7: Subscription Upgrades & Gated Capabilities
- **Current Breakdown:** `PlusPaywallView.swift:242-251` and `PremiumPaywallView.swift:248-257` run `Task.sleep(nanoseconds: 1_000_000_000)` and set `appState.isPlusMember = true` or `isPremiumMember = true`.
- **Failure:** `SubscriptionService.swift` is not invoked. Transactions are not processed, restored, or verified. Furthermore, becoming Plus/Premium unlocks zero new functional code paths.

---

## 4. Missing Feature Work by Domain

### 1. Ingestion Features
- **SwiftUI PhotosPicker Integration:** Replace the dummy button in `HomeEmptyStateView` with `PhotosPicker(selection: $selectedPhotoItem, matching: .images)` from `PhotosUI`.
- **Smart Album Screenshot Scanner:** Wire `HomeViewModel.loadRecentScreenshots()` to fetch real `PHAsset` items and provide a thumbnail gallery of recent screenshots.
- **Document Picker (PDF/Files):** Implement `.fileImporter(isPresented:allowedContentTypes:)` for `.pdf` and image types to fulfill the advertised Premium document import capability.

### 2. Extraction & Inference Features
- **Pipeline Execution on Selected Assets:** Ensure `ScanViewModel.scanImage(_:modelContext:)` or `scanAsset(_:modelContext:)` runs immediately upon selecting a photo or screenshot.
- **Correct "Doors vs Show" Priority:** Update `EventExtractionService.swift:901-912` so that when both doors and show times are detected, the **show time** becomes the event `startDate`, and the door time is added to `notes` or structured metadata.

### 3. Review/Edit UX
- **Live EventReviewViewModel Binding:** Instantiate `EventReviewViewModel(services: candidate:)` inside `EventReviewEditView` instead of raw `@State` mirrors.
- **Working Ambiguous-Date Toggle:** Ensure tapping "Swap Month & Day" in the ambiguity banner executes `viewModel.swapMonthAndDay()`, updating the displayed date and underlying `DateComponents`.

### 4. Calendar & Reminder Creation
- **Explicit Execution on User Confirmation:** In `EventReviewEditView`, the primary button must `await viewModel.commitEvent(modelContext:)`.
- **Calendar & List Selection:** Allow user to pick destination calendar from `viewModel.availableCalendars` and reminder list from `viewModel.availableReminderLists`.
- **External Identifier Storage:** Ensure returned `EKEvent.eventIdentifier` and `EKReminder.calendarItemIdentifier` are stored on `SavedEvent` in SwiftData.

### 5. Notifications & Follow-Up Alerts
- **Notification Rescheduling in Schedule Editor:** In `ReminderScheduleEditorView.swift:295-305`, replace `appState.updateAlerts` with real calls to `notificationService.scheduleLocalNotifications` and `reminderService`.
- **Deep-Link Event Routing:** Add `.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DateSnapDeepLinkEvent")))` in `ContentView.swift` to navigate directly to `.savedEventDetail(event)`.

### 6. Subscription-Gated Functionality
- **Real StoreKit 2 Purchasing:** Wire `PlusPaywallView` and `PremiumPaywallView` to `subscriptionService.purchase(product:)` and `subscriptionService.restorePurchases()`.
- **Gating Enforcement:** Gate automated screenshot scanning behind `subscriptionService.currentTier >= .plus` and document/PDF import behind `subscriptionService.currentTier == .premium`.

### 7. History, Archive & Triage
- **SwiftData `@Query` in History:** Refactor `HistoryArchiveView` to query `SavedEvent` from SwiftData.
- **Triage Actions:** Add working swipe actions or buttons for **Archive**, **Triage/Draft**, and **Delete** that mutate `SavedEvent.statusRaw` and commit to `modelContext`.

### 8. Offline Behavior
- Ensure all extraction, OCR, and EventKit operations remain completely local and testable in Airplane Mode with zero network dependencies.

### 9. Error Recovery & Empty States
- **Settings Deep-Links:** In `CalendarPermissionDeniedView` and `NotificationPermissionDeniedView`, replace the toast with:
  ```swift
  if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
  }
  ```
- **Permission State Synchronization:** When returning from iOS Settings, refresh `authorizationStatus()` dynamically in `HomeViewModel`.

### 10. Production-State Cleanup
- Remove the 3 hardcoded sample events from `AppState.events` for production runs.
- Remove simulated permission toggles (`appState.calendarPermissionDenied = false`).

---

## 5. Prototype-to-Product Cleanup

| Location | Prototype Code | Why It Blocks Production | Required Production Replacement |
|---|---|---|---|
| `AppState.swift:53-57` | Hardcoded `sampleNeonSunset`, `sampleDentalCheckup`, `sampleSummerMixer`. | Pollutes real user data; masks persistence failures. | Empty array by default; load persisted `SavedEvent` records via SwiftData. |
| `AppState.swift:63-68` | `@Published var isPlusMember = false`, `calendarPermissionDenied = false`. | Bypasses `SubscriptionService` and `EKEventStore` authorization status. | Derive membership from `SubscriptionService.currentTier` and permissions from services. |
| `HomeEmptyStateView.swift:248-280` | `Task.sleep` delays opening hardcoded mock events. | Completely prevents scanning actual images. | Wire to `ScanViewModel.scanAsset` and `PhotosPicker`. |
| `HomeEmptyStateView.swift:353-365` | `showSampleResult.toggle()` opening static text. | Fails to demonstrate real OCR/inference to prospective users. | Feed a bundled sample flyer UIImage through `ScanViewModel.scanImage`. |
| `EventReviewEditView.swift:544-560` | `Task.sleep` saving to in-memory `appState.events`. | No events are ever created in iOS Calendar or Reminders. | Bind to `EventReviewViewModel.commitEvent(modelContext:)`. |
| `PlusPaywallView.swift:242-251` | `Task.sleep` setting `appState.isPlusMember = true`. | Purchases are fake; violates App Store Guidelines and fails StoreKit. | Invoke `subscriptionService.purchase(product:)`. |
| `ReminderScheduleEditorView.swift:295-304` | Fake delay updating `appState.updateAlerts`. | Alerts are never scheduled with the system notification center. | Call `notificationService.scheduleLocalNotifications`. |
| `CalendarPermissionDeniedView.swift:189-191` | `appState.showToast("Opening iOS Settings...")`. | Traps user in denied state; cannot grant permissions. | Open `UIApplication.openSettingsURLString`. |

---

## 6. Priority Roadmap

### P0 — Core Feature Completion (Must be done for usable beta)

#### Task 1: Wire Real Photo Library Ingestion & PhotosPicker
- **Files:** `Sources/DateSnap/Views/HomeEmptyStateView.swift`, `Sources/DateSnap/ViewModels/ScanViewModel.swift`
- **Behavior:** Add SwiftUI `PhotosPicker` to "Choose from Photo Library". When an image is picked or "Scan Recent Screenshots" is tapped, load the `UIImage` and pass it to `ScanViewModel.scanImage(_:modelContext:)`.
- **Dependencies:** `PhotoLibraryService`, `ScanViewModel`.
- **Acceptance Criteria:** Selecting a screenshot from the simulator/device library triggers real Vision OCR and displays the scanned candidate in `EventReviewEditView`.

#### Task 2: Connect Review Flow to Calendar & Reminders Execution
- **Files:** `Sources/DateSnap/Views/EventReviewEditView.swift`, `Sources/DateSnap/ViewModels/EventReviewViewModel.swift`
- **Behavior:** Refactor `EventReviewEditView` to take `EventReviewViewModel`. Tapping "Save Event to Calendar" invokes `await viewModel.commitEvent(modelContext:)`.
- **Dependencies:** `CalendarService`, `ReminderService`, `NotificationService`, `SwiftData`.
- **Acceptance Criteria:** Tapping Save creates an event in the native Apple Calendar app and alerts in Apple Reminders with matching titles, locations, and times.

#### Task 3: SwiftData Persistence & Cold-Launch Continuity
- **Files:** `Sources/DateSnap/Views/HistoryArchiveView.swift`, `Sources/DateSnap/Models/AppState.swift`
- **Behavior:** Remove seeded sample events from `AppState`. In `HistoryArchiveView`, use `@Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]`.
- **Dependencies:** `SwiftDataEntities.swift`.
- **Acceptance Criteria:** Events saved during a session remain visible, searchable, and filterable in History after force-quitting and relaunching the app.

#### Task 4: StoreKit 2 Purchase & Entitlement Wiring
- **Files:** `Sources/DateSnap/Views/PlusPaywallView.swift`, `Sources/DateSnap/Views/PremiumPaywallView.swift`, `Sources/DateSnap/Services/SubscriptionService.swift`
- **Behavior:** Replace `Task.sleep` in paywalls with `try await subscriptionService.purchase(product:)` and `try await subscriptionService.restorePurchases()`. Bind tier display to `subscriptionService.currentTier`.
- **Dependencies:** StoreKit 2, `DateSnap.storekit`.
- **Acceptance Criteria:** Purchasing in the StoreKit testing environment unlocks the corresponding tier badge and capabilities without errors.

---

### P1 — Product Completeness (Before calling app feature complete)

#### Task 5: Fix "Doors vs Show" Priority & Note Preservation
- **Files:** `Sources/DateSnap/Services/EventExtractionService.swift:894-912`
- **Behavior:** In `DateInference.extractTimeWindow`, check for `isShow`. If present, assign the show time as the primary start time. Store the door time in the event notes snippet (`Doors open at X`).
- **Dependencies:** `EventExtractionService`.
- **Acceptance Criteria:** A flyer stating "Doors 7:00 PM / Show 8:30 PM" produces a candidate with `startDate` at 8:30 PM and notes stating "Doors open at 7:00 PM".

#### Task 6: Actionable Notification Deep-Linking
- **Files:** `Sources/DateSnap/ContentView.swift`, `Sources/DateSnap/Models/AppState.swift`, `Sources/DateSnap/Services/NotificationService.swift`
- **Behavior:** Listen for `NotificationCenter.default.publisher(for: NSNotification.Name("DateSnapDeepLinkEvent"))` in `ContentView` and route `appState.activeModal` to `.savedEventDetail(event)`.
- **Dependencies:** `NotificationService`, `SwiftData`.
- **Acceptance Criteria:** Tapping a scheduled local notification banner opens DateSnap directly into the saved event detail screen.

#### Task 7: Interactive "Try Sample Flyer" Flow
- **Files:** `Sources/DateSnap/Views/HomeEmptyStateView.swift`, bundled asset or generated test flyer UIImage.
- **Behavior:** Tapping "Try Sample Flyer" passes a sample concert flyer image into `ScanViewModel.scanImage(_:)` and launches `EventReviewEditView` with real parsed candidates.
- **Dependencies:** `ScanViewModel`, `HomeEmptyStateView`.
- **Acceptance Criteria:** Users can experience the end-to-end extraction and review flow on first launch without granting photo permissions.

#### Task 8: Settings Deep-Link Recovery
- **Files:** `Sources/DateSnap/Views/CalendarPermissionDeniedView.swift`, `Sources/DateSnap/Views/NotificationPermissionDeniedView.swift`
- **Behavior:** Replace toast placeholders with `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`.
- **Dependencies:** UIKit.
- **Acceptance Criteria:** Tapping "Open iPhone Settings" launches the iOS Settings page for DateSnap.

---

### P2 — Polish & Advanced Features (Post-Beta)

#### Task 9: Multi-Page PDF & iOS Files Import (Premium)
- **Files:** New `DocumentPickerService.swift`, `Sources/DateSnap/Views/HomeEmptyStateView.swift`
- **Behavior:** Add `.fileImporter` supporting PDF and render each PDF page into a `UIImage` using `PDFKit` (`PDFPage.draw`) for batch OCR. Gate behind `SubscriptionTier.premium`.
- **Dependencies:** `PDFKit`, `SubscriptionService`.
- **Acceptance Criteria:** Premium users can import a multi-page event itinerary PDF and extract all dates into review candidates.

#### Task 10: History Triage & Batch Cleanup
- **Files:** `Sources/DateSnap/Views/HistoryArchiveView.swift`
- **Behavior:** Add swipe-to-archive, swipe-to-delete, and batch triage actions on persisted `SavedEvent` items.
- **Dependencies:** SwiftData `ModelContext`.
- **Acceptance Criteria:** Swiping an item in History transitions its status between Saved, Archived, and Deleted with immediate persistence.

---

## 7. Concrete Engineering Tasks

```markdown
- [ ] Task 1.1: Import PhotosUI into HomeEmptyStateView.swift and add PhotosPicker binding.
- [ ] Task 1.2: Instantiate ScanViewModel in HomeEmptyStateView using @Environment(\.services).
- [ ] Task 1.3: Pass selected PhotosPicker image data to ScanViewModel.scanImage(_:modelContext:).
- [ ] Task 1.4: Bind HomeEmptyStateView sheet presentation to ScanViewModel.stage == .complete(candidates).
- [ ] Task 2.1: Refactor EventReviewEditView.swift to accept EventReviewViewModel.
- [ ] Task 2.2: Bind "Save Event to Calendar" in EventReviewEditView to viewModel.commitEvent(modelContext:).
- [ ] Task 2.3: Connect Ambiguous Date swap button to viewModel.swapMonthAndDay().
- [ ] Task 3.1: Remove mock sample events from AppState.swift initialization.
- [ ] Task 3.2: Refactor HistoryArchiveView.swift to use @Query for SavedEvent entities.
- [ ] Task 3.3: Implement SwiftData modelContext.delete and status updates in HistoryArchiveView.
- [ ] Task 4.1: Connect PlusPaywallView CTA to subscriptionService.purchase(product:).
- [ ] Task 4.2: Connect PremiumPaywallView CTA to subscriptionService.purchase(product:).
- [ ] Task 4.3: Connect "Restore" buttons in both paywalls to subscriptionService.restorePurchases().
- [ ] Task 5.1: Update EventExtractionService.swift line 901 to prioritize isShow over earliest door time.
- [ ] Task 5.2: Append door time to event notes in EventExtractionService.
- [ ] Task 6.1: Add NotificationCenter deep-link observer in ContentView.swift.
- [ ] Task 6.2: Route active modal to .savedEventDetail when deep link arrives.
- [ ] Task 7.1: Replace static disclosure in HomeEmptyStateView with real sample flyer image scan.
- [ ] Task 8.1: Replace toast in CalendarPermissionDeniedView with UIApplication.openSettingsURLString.
- [ ] Task 8.2: Replace toast in NotificationPermissionDeniedView with UIApplication.openSettingsURLString.
```

---

## 8. Definition of Feature Complete

DateSnap is considered **feature complete** when all of the following conditions are verified at runtime on an iOS 18 device/simulator:

1. **Working Ingestion Paths:**
   - User can select any photo or flyer via `PhotosPicker` and initiate scanning.
   - User can tap "Scan Recent Screenshots" and have the app read real images from the PhotoKit smart album.
   - User can tap "Try Sample Flyer" and observe the live OCR/inference pipeline process a real image without granting photo permissions.
2. **Deterministic Extraction & Inference:**
   - Text is extracted on-device via Vision and passed into `EventExtractionService`.
   - Ambiguous dates (e.g. `04/05/2026`) display the ambiguity banner and correctly swap month/day upon user tap.
   - Shows with both doors and show times correctly set start time to the show time and preserve door times in notes.
3. **True Calendar & Reminders Integration:**
   - Saving an event writes an `EKEvent` to Apple Calendar and an `EKReminder` to Apple Reminders with requested alarm offsets.
   - Saves happen **only** after explicit user confirmation in `EventReviewEditView`.
4. **Actionable Notifications:**
   - Pre-event alert notifications are scheduled with `UNUserNotificationCenter`.
   - Tapping an alert banner deep-links the user into DateSnap and displays the saved event details.
5. **Persistent History Across Cold Launches:**
   - Saved events persist in SwiftData.
   - Force-quitting and reopening the app loads saved events in History.
   - Search and status filters operate on real persisted records.
6. **Functional StoreKit 2 Subscription Gating:**
   - Paywalls fetch real products, execute purchases, and restore transactions via StoreKit 2.
   - Active entitlements dynamically unlock Plus (automatic screenshot detection) and Premium features.
7. **Offline-First Resilience:**
   - Entire scan, extraction, review, and calendar-save workflow succeeds in Airplane Mode without network connectivity.
8. **Graceful Permission Recovery:**
   - Denied permission screens link directly to iOS Settings via `UIApplication.openSettingsURLString`.
