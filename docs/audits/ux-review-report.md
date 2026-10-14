# Pencil’d Bulk Scan & Bulk Insert UX Review

*Prepared as a senior mobile UX researcher, iOS product designer, accessibility specialist, and launch-readiness product owner.*

---

## A. Executive assessment

**Verdict:** **Needs targeted refinement** – the workflows are functional and the design‑system compliance is solid, but several points create uncertainty, friction, or risk of accidental calendar/reminder changes. The product can ship, but a short list of fixes will markedly improve confidence and reduce support risk.

**Top 3‑5 highest‑risk usability issues**

| # | Issue | Why it matters |
|---|-------|----------------|
| 1 | **No explicit “confirm before bulk save” gate** – the *Save All* bar commits every actionable event immediately; there is no modal “Are you sure you want to add X events to your calendar/reminders?” | Users may unintentionally populate their calendar/reminders, especially when many events are selected. |
| 2 | **Free‑scan limit revealed only after the batch bar appears** – the *batch allowance prompt* appears at the bottom of the selection screen, many taps after the user has already ticked items. The limit is not visible during selection, so users can unknowingly exceed their quota. | Surprise quota‑exhaustion leads to failed scans and frustration. |
| 3 | **Ambiguous “actionable count” in the Save All label** – `Save All (n)` shows `actionableCount` which may differ from the total displayed events; users cannot quickly tell how many will actually be saved. | Raises doubt about what “Save All” really does. |
| 4 | **Missing pre‑save destination confirmation** – after review, the workflow commits events to whatever destination was previously selected (or default) without a final “Confirm destinations” step. | Users may not realize events will go to a specific calendar/reminder list, increasing risk of wrong placement. |
| 5 | **No clear “undo/retract” path after a failed save** – the failure alert simply says “Some Events Did Not Save” with an OK button; there is no way to see which events failed or to retry only the failed ones. | Users lose visibility of partial failures, eroding trust. |

---

## B. Findings table

| Severity | Workflow stage | Screen / state | Problem | User impact | Heuristic violated | Recommendation | Replacement copy / UI behavior |
|----------|----------------|----------------|---------|-------------|-------------------|----------------|--------------------------------|
| **Critical** | Bulk‑scan → Save All | *Save All* bar (BatchReviewView) | No confirmation prompt before bulk‑save; `Save All` commits immediately. | Users may accidentally add many events to calendar/reminders. | **Error prevention** (Nielsen) | Add a *confirmation sheet* (“Save X events to • Calendar • • Reminders •?”) with *Cancel* and *Save* actions. |
| **High** | Bulk‑scan selection | *RecentScreenshotsView* – batch allowance prompt appears after items are selected. | Users may select more than their free‑scan allowance without seeing the limit. | Surprise quota exhaustion; failed scans. | **Visibility of constraints** | Show the remaining free‑scan count *while selecting* (e.g., “X of Y selected (Z free scans left)”). Update the count in real time as selections change. |
| **High** | Bulk‑scan selection | *RecentScreenshotsView* – “Select all”/“Deselect all” button only appears when `isSelecting`; no visual cue of total allowed. | Users cannot gauge how many they can select before the prompt. | Same as #2. | **Affordance clarity** | Permanently display “Free scans left: N” at the top of the selection screen, disabled‑gray “Select all” when at limit. |
| **Medium** | Bulk‑review → Save All | *BatchReviewView* – `Save All (actionableCount)` label. | `actionableCount` may not equal total events; users unsure how many will actually save. | Confusion, mistrust. | **Label clarity** | Change label to “Save All (X of Y saved, Z pending)” or show a breakdown (e.g., “Save 7 events – 3 need review”). |
| **Medium** | Bulk‑review | *BatchReviewView* – no final “Confirm destinations” step before *Save All*. | Users may not know which calendar/reminder list events will join. | Wrong calendar/reminder placement. | **User control** | Add a “Destinations” pill bar just above *Save All* showing the selected calendar/reminder list; allow users to change before saving. |
| **Low** | Bulk‑scan progress | *BatchScanProgressOverlay* – “Private, on‑device processing” note is small and may be missed. | Users may wonder if data leaves the device. | Reduced perceived privacy. | **Transparency** | Promote the note to a persistent banner (“All processing on‑device”) during scanning. |
| **Low** | Bulk‑review | *BatchEventCard* – “PossibleDuplicateBanner” appears but has no dismiss action other than “Keep separate”. | Users may not understand how to handle duplicates. | Potential duplicate events. | **Error handling** | Add a small “Mark as not duplicate” action or inline explanation when the banner appears. |
| **Low** | Bulk‑insert | *PlusPaywallView / PremiumPaywallView* – CTA titles “UPGRADE TO PLUS/PREMIUM” are consistent (per audit) but the paywall appears multiple times in the same flow (selection limit, likely‑event filter, post‑save failure). | Paywall fatigue; users may tap “Cancel” reflexively. | Drop‑off during bulk flow. | **Friction reduction** | Consolidate paywall triggers where possible; use inline “Upgrade” links only when the user explicitly requests extra capacity. |
| **Low** | Accessibility | Various `PDStatusBadge`, `PDPrimaryButtonStyle`, etc. – ensure VoiceOver reads “Saved” / “Failed” clearly. | Screen‑reader users may miss status. | Accessibility non‑compliance. | **VoiceOver** | Verify each badge’s `accessibilityLabel` is set; add “Saved to Calendar” / “Failed to save” as needed. |

---

## C. Workflow friction map

| Step | User goal | Likely uncertainty / friction | Failure risk | Recommended UX safeguard |
|------|-----------|------------------------------|--------------|--------------------------|
| **1. Select sources** | Choose multiple screenshots/PDFs to scan. | • “How many can I pick?”<br>• “What counts as a scan?” | Selecting > free‑scan limit → scan fails. | Persistent “Free scans left: N” counter; disable “Select all” at limit. |
| **2. Confirm batch** | Press *Scan Batch* → start OCR. | • “Will I exceed my quota?”<br>• “What happens if I tap *Select all*?” | Accidental over‑selection → user thinks scan broken. | Real‑time quota display; “Select all” disabled/labelled when at limit. |
| **3. Process & progress** | Watch per‑item status while OCR runs. | • “Which items are still scanning?”<br>• “Why does one show ‘No dates found’?” | Mis‑reading of status → user assumes failure. | Per‑item status chips with concise text (“No dates found”, “1 event found”). |
| **4. Review extracted events** | Inspect each event, edit details, decide what to keep. | • “Which events are ready to save?”<br>• “What does the confidence % mean?” | Users may skip important events or save flawed ones. | Status badge + confidence tier label; inline “Edit” per event; “PossibleDuplicateBanner” with action. |
| **5. Resolve exceptions** | Discard, keep, or edit items flagged as failed/duplicate. | • “Can I re‑scan a failed item?”<br>• “What happens if I discard?” | Loss of work if discard is accidental. | Destructive “Discard” actions behind confirmation dialog; provide “Re‑scan” option for failed items. |
| **6. Choose destination** | Pick calendar/reminder list for bulk insert. | • “Where will these go?”<br>• “Can I change after saving?” | Events saved to wrong calendar → user confusion. | “Destinations” pill bar shown just before *Save All*; allow in‑place editing. |
| **7. Bulk Insert** | Confirm and save all selected events. | • “Exactly how many will be created?”<br>• “Can I undo?” | Accidental bulk calendar insertion. | Confirmation sheet: “Save X events to • Calendar • • Reminders •?” with *Cancel* / *Save*. |
| **8. Post‑insert feedback** | See success/failure summary. | • “Which events failed?”<br>• “Can I re‑attempt only the failures?” | Users left in the dark about partial failures. | Toast + detailed alert listing saved / failed counts; provide “Retry failed” button. |

---

## D. State coverage audit

| State | Current coverage | Gap / weakness | Suggested fix |
|-------|----------------|----------------|--------------|
| **Empty batch** (no events detected) | `emptyState` in `BatchReviewView` shows “Nothing left to review”. | Missing when batch ends with 0 actionable events after filtering. | Keep; already present. |
| **No date found** | Shown per‑item via `skipReason` (“No event date found”). | Users may not understand why an item was skipped. | Add tooltip “No readable date detected in image”. |
| **Ambiguous date/time** | Not explicitly labelled; confidence tier shows high/medium/low. | Users may be unsure if the date is correct. | Add inline “Tap to adjust date” on the chip. |
| **Duplicate event** | `PossibleDuplicateBanner` appears; dismiss only via “Keep separate”. | No option to merge or ignore. | Add “Merge” and “Skip” actions. |
| **Partial scan failure** (some items failed) | `saveAll` bar shows “\(summary.savedCount) of … saved — tap Save All to retry”. | Users may not know which items failed. | Include a “View failures” link that opens a sheet listing failed items. |
| **Partial insert failure** (some items saved, some not) | Failure alert “Some Events Did Not Save”. | No granularity of which events failed. | Alert with list of saved vs. failed; “Retry failed” button. |
| **Permission denied** (notifications) | `showNotificationRecovery` sheet appears; user can re‑request permission. | Sheet may be dismissed without understanding next steps. | Add “Settings” shortcut that opens iOS notification settings. |
| **Network / service interruption** | Not applicable – all OCR is on‑device. | N/A | Document as “offline‑capable”. |
| **User cancellation** | User can dismiss at any point via *Close* button. | No explicit “unsaved changes” warning when leaving review screen. | Add “Leave review? Discard changes?” confirmation when user closes/dismisses. |
| **Background / resume** | Scans persist via `AppState`; progress overlay shown on return. | User may return to a completed batch without knowing state. | Restore last summary and highlight “Save All” if events remain actionable. |
| **All items completed successfully** | `saveAll` bar shows “All X events saved”. | No celebratory feedback beyond toast. | Add subtle confetti or “All saved!” banner (optional, respecting calm voice). |
| **No valid items remain for insertion** | After review, if all events are discarded/failed, *Save All* bar hidden. | Users may wonder why nothing happened. | Show “No events to save” message with gentle explanation. |

---

## E. Prioritized recommendations

### 1. Top 10 fixes before launch

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | **Add a “Confirm Save All” sheet** (modal with “Save X events to •Calendar• •Reminders•” and Cancel/Save). | Medium (UI + state) | Prevents accidental calendar insertion (Critical). |
| 2 | **Persist free‑scan count during selection** – display “Free scans left: N” at top of `RecentScreenshotsView` and update in real time. | Low (counter + visibility) | Eliminates surprise quota exhaustion (High). |
| 3 | **Show “actionable / total” breakdown** in *Save All* label: “Save All (X of Y actionable)”. | Low (text change) | Clears ambiguity about how many will be saved (Medium). |
| 4 | **Add a “Destinations” pill bar** just before *Save All* showing selected calendar/reminder list, editable. | Medium (new view + binding) | Gives users control over target destination (Medium). |
| 5 | **Detail the failure list** in the “Some Events Did Not Save” alert – list each failed event with a “Retry” button. | Medium (alert redesign) | Restores trust after partial failures (High). |
| 6 | **Real‑time “Select all” disabled** when at or over free‑scan limit; add gentle “You’ve reached your free‑scan limit” inline. | Low (state check) | Prevents over‑selection (High). |
| 7 | **Promote the “on‑device processing” banner** to a persistent bar during scanning. | Low (banner UI) | Reinforces privacy assurance (Low). |
| 8 | **Add VoiceOver accessibility labels** to all `PDStatusBadge`s and primary CTA (“Saved to Calendar”, “Failed to save”). | Low (label strings) | Improves screen‑reader compliance (Low). |
| 9 | **Add “Leave review?” confirmation** when user dismisses the batch review screen unsaved. | Low (alert) | Prevents accidental loss of edited events (Medium). |
|10 | **Consolidate paywall triggers** – show the paywall only once per session (e.g., first time the user hits the free‑scan limit) and reuse the same sheet. | Medium (flow refactor) | Reduces paywall fatigue (Low). |

### 2. Quick wins (low effort / high impact)

| # | Quick win |
|---|-----------|
| 1 | Update the *Save All* label to show “Save All (X of Y)”. |
| 2 | Add a persistent “Free scans left: N” line at the top of the selection screen. |
| 3 | Ensure every `PDStatusBadge` has an explicit `accessibilityLabel` (e.g., “Saved to Calendar”). |
| 4 | Disable “Select all” when the user has hit the free‑scan limit and show a brief inline message. |
| 5 | Add a “Re‑try failed” button in the post‑save failure alert. |

### 3. Improvements that can wait until post‑launch

| # | Improvement |
|---|------------|
| 1 | Animated confetti or “All saved!” celebration banner (visual polish only). |
| 2 | Merge‑duplicate action in the `PossibleDuplicateBanner`. |
| 3 | In‑app tutorial/tooltip for confidence tier meaning. |
| 4 | Dynamic‑Type scaling test across all font tokens (already using PDFont – likely fine). |
| 5 | Custom “Merge events” UI for combining two duplicate events into one. |

### 4. Critical decisions requiring product‑owner input

| Decision | Options | Recommendation |
|----------|---------|----------------|
| **Whether to require an explicit “Confirm Save All” modal** (could add friction vs. risk of accidental calendar changes). | a) Always show modal.<br>b) Show only when > N events selected (e.g., > 5). | *Owner*: Choose (a) for maximum safety, or (b) with a configurable threshold based on data‑loss analytics. |
| **Free‑scan limit behavior** – hard cap vs. graceful degradation (allow extra scans with a prompt to upgrade). | a) Hard cap, block further selection.<br>b) Allow extra scans, show upgrade prompt inline. | *Owner*: Based on business model; recommend (a) for privacy‑first positioning, (b) if conversion metrics justify. |
| **Destination default** – use the user’s primary calendar/reminder list automatically vs. always ask. | a) Auto‑default to primary list.<br>b) Always prompt before bulk insert. | *Owner*: Given the product’s “local‑first, user‑control” ethos, (b) is preferred, but (a) can be a opt‑in setting. |

---

## F. Reconciliation with the current implementation (2026-10-14)

This report was added to the visual-refresh work after the later batch-flow
changes landed. The following findings are resolved or narrowed by the current
source:

| Audit finding | Current evidence | Status |
|---|---|---|
| Free-scan limit is invisible during selection | `RecentScreenshotsView.batchScanBar` shows the selected count and remaining free scans in real time; `HomeEmptyStateView` also exposes the allowance. | Resolved |
| Over-limit selection cannot be recovered | The allowance prompt calls `trimSelection(to:)`, retaining the allowed assets before scanning. | Resolved |
| Destinations are hidden during review | Each `BatchEventItem` card and the Save All bar show selected calendar and reminder destinations before saving. | Resolved; destination editing remains per event. |
| Bulk Save All has no confirmation | `BatchReviewView` now presents a confirmation dialog with the event count and destination summary before `saveAll()`. | Resolved; runtime verification remains pending. |
| Save All count is ambiguous | The bar now says “Save All (actionable of total)” and explains the ready-to-save count. | Resolved; runtime verification remains pending. |
| Failed events are opaque | `BatchSaveSummary.failedMessages` includes the screenshot label, event title, and failure message. After a partial save, `actionableCount` leaves failed events available for a focused `Save All` retry. | Resolved; runtime verification remains pending. |
| Discard risks accidental loss | Unsaved event discard uses a destructive confirmation dialog. | Resolved |
| On-device processing is easy to miss | Scan progress and batch progress display the private on-device processing message. | Resolved; runtime visibility remains pending. |

The only implementation finding still open is runtime VoiceOver verification
for status badges and failure states. Batch Review now warns before dismissing
unsaved work. Duplicate handling has a “Keep separate” path; merge support
remains intentionally deferred. The executive assessment above reflects the
earlier snapshot; this reconciliation is the current source-based status.

### Closing note

The bulk scan → review → insert chain is already well‑structured and respects the design‑system tokens (`PDColor.*`, `PDFont.*`, `PDSpacing.*`, `PDRadius.*`). The most critical gap is the **lack of a pre‑save confirmation gate** and the **opaque free‑scan‑limit communication**. Adding the ten fixes above will bring the workflow to a launch‑ready level of confidence, minimal error risk, and a smooth, transparent user experience that aligns with Pencil’d’s calm, capable, privacy‑conscious brand voice.
