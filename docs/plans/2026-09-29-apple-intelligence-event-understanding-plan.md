# DateSnap On-Device Intelligence Architecture Plan

**Date:** 2026-09-29  
**Status:** Implemented (Phases 0–4) — on-device verification pending; live-route latency 10–20 s per model pass  
**Scope:** On-device Apple Intelligence for event understanding, plus reusable intelligence augmentation across DateSnap services.  
**Deployment baseline:** iOS 18.0, as declared by `Package.swift` and `project.yml`.

## 1. Executive summary

DateSnap already has a strong local-processing foundation: Vision OCR retains text geometry and confidence, `EventExtractionService` applies deterministic temporal and semantic heuristics, `ScanViewModel` coordinates OCR, extraction, deduplication and SwiftData persistence, and the service protocols are composed through `ServiceContainer`. `ContentView` constructs and injects `ScanViewModel`; the home and scan flows consume it. This proposal extends those seams and keeps EventKit, PhotoKit, StoreKit and notification side effects under their existing services.

Add an optional `EventUnderstandingPipeline` around the deterministic extractor. On eligible devices running the Foundation Models API, the pipeline interprets OCR evidence into typed, ranked event hypotheses. A deterministic validator checks every proposed value against the OCR evidence and current parser output. The pipeline returns a review bundle containing the preferred interpretation, material alternatives, field provenance, concise evidence explanations, action suggestions and confidence/ambiguity metadata. The baseline parser remains available on every supported iOS 18 device and runs when Apple’s on-device model cannot be used.

The initial product slice should improve one user-initiated scan on supported devices: resolve title/venue/organizer roles, associate dates with their labels, distinguish doors from show time, and show evidence-backed alternatives where a wrong choice matters. It should never silently write an inferred event to Calendar or Reminders. Later phases can add photo triage, cross-screenshot duplicate clusters, reminder strategies and premium batch automation.

Three implementation details make this plan specific to the current code:

- `ExtractedCandidateData` already carries title, date, venue, RSVP, confidence, assumed-year and ambiguity fields, timezone, dedupe key, contacts, notes and raw OCR context. Keep and extend that baseline rather than replacing the parser.
- `DateInference.resolveAssumedYear` recognizes a fixed 2024–2039 year window, while `computeDedupeKey` includes the PhotoKit asset identifier. The first needs anchor-relative handling; the second is useful for repeat scans of one asset but cannot identify the same event across different screenshots.
- The current `ScanViewModel.scanPages` path persists a `ScannedAsset` and candidates before review. Preserve that workflow with a separate, versioned interpretation bundle for alternatives and provenance, then apply the user’s selection to the canonical `EventCandidate`.

## 2. Apple Intelligence opportunity map

| Capability | Product behavior | Initial classification |
|---|---|---|
| Semantic role labeling | Separate event title, tagline, performer, venue, organizer, sponsor and boilerplate using OCR text plus line geometry. | Practical, single-scan assist |
| Temporal interpretation | Associate each date/time with event start, doors, show, end, RSVP deadline, ticket sale or unrelated date. | Practical, high-value |
| Ranked interpretations | Show a best interpretation and a small number of materially different alternatives. | Practical, core trust feature |
| Evidence explanations | Point to the OCR line or region and state the observable cue supporting a field. | Practical, core trust feature |
| Action intent | Identify RSVP, ticket, registration, call and email actions with their evidence-linked URL/contact and any deadline. | Practical, user-confirmed action |
| Event reconstruction | Combine sparse poster text, line position, explicit labels and date clues into a coherent draft while marking assumptions. | Practical with strict evidence checks |
| Scan worthiness | Predict whether a screenshot likely contains an event before spending time on full OCR or semantic interpretation. | Practical for photo triage; deterministic screen first |
| Event category and duration | Suggest a broad category and a duration prior when no end time exists. | Practical as an editable suggestion |
| Recurrence signals | Recognize “every Thursday,” “first Friday,” a series name or edition number; offer a recurrence workflow. | Useful, requires explicit confirmation |
| Cross-screenshot clustering | Cluster similar event candidates using normalized title/date/venue and local semantic similarity. | Premium archive feature after dedupe evaluation |
| Personal reminder strategy | Recommend reminders using event type, RSVP deadline, lead time and optional user preferences. | Premium or opt-in convenience |
| Travel and follow-up planning | Offer a travel buffer or post-event action when the user provides the needed preference/context. | Exploratory; no route-time claims without a route source |

The public Foundation Models framework supplies local text reasoning on supported OS/device combinations. Vision remains responsible for image OCR and geometry. The model receives a compact, local OCR representation; it does not receive the photo library or an unfiltered image collection.

## 3. EventExtractionService enhancement plan

### Current baseline and limits

`EventExtractionService` accepts raw text or `OCRResult`, segments OCR into event blocks and calls `DateInference` to create `ExtractedCandidateData`, then materializes `EventCandidate` models. The deterministic code already filters likely receipts and shipping notices, ranks a title using OCR size/width/position, parses date and time patterns, detects doors/show markers, extracts venue/address and contact data, records an assumed year and ambiguity flags, and generates a dedupe key. `OCRService` contributes recognition confidence, normalized bounding boxes and a font-size proxy.

The next version should retain this evidence collection and improve the interpretation and association stages:

1. **Build an evidence map.** Give every OCR line a stable line identifier, block identifier, bounding box, OCR confidence and source text. Derive compact features such as line group, spatial proximity and font-size rank. Keep the original text available locally for review and correction.
2. **Run deterministic extraction first.** Produce typed `TemporalEvidence`, exact URLs/emails/phone numbers, address candidates, known labels, year assumptions and baseline candidate scores. Preserve the parser’s raw findings even when a semantic interpretation is attempted.
3. **Gate an on-device semantic pass.** Invoke Foundation Models for low-margin title/role choices, conflicting dates, noisy text, unlabeled time pairs or an apparent registration deadline. Skip it for empty/receipt-like material and for already-clear scans where it adds no value.
4. **Request constrained output.** Ask for typed fields and evidence-line references: event title, tagline, performer/organizer/venue, event date, doors/show/end times, RSVP/ticket/registration intent, broad category, recurrence signal, notes summary and alternatives. The model may classify or select evidence; the validator must reject unsupported dates, URLs, contacts and locations.
5. **Validate, rank and merge.** Use deterministic checks for valid dates, time ordering, URL syntax, field bounds, duplicate fields and line-reference existence. Preserve explicit high-confidence values. Do not treat a model’s self-reported confidence as calibrated confidence. Rank interpretations using parser evidence, OCR quality, semantic-label agreement and the margin between candidate choices.
6. **Return a review bundle.** Select one best interpretation, retain only alternatives that change a material field, add evidence-linked explanations and propose a follow-up question only where the choice can materially affect the saved event.

### Specific inference upgrades

- **Title versus venue, organizer and tagline:** Combine visual prominence with semantic role labels and neighboring lines. A large “Summer Nights” phrase can remain the title while “Rooftop Sessions” is a series and “Presented by…” is the organizer. Preserve meaningful performer and sponsor entities in structured metadata or notes.
- **Multiple dates and time labels:** Parse every temporal fragment independently and attach its OCR evidence. Classify event date, doors, show, end, RSVP cutoff, ticket-sale date and unrelated dates. The current time parser can return one window or a block-level set of times; the enhanced pass should associate each time with its own label and date before creating candidates.
- **Show time versus doors time:** Retain the current deterministic doors/show rules as evidence, then use semantic labels and line association to resolve posters with several time pairs. Explain the result, such as “8:30 PM selected from the line labeled Show; 7:00 PM is retained as doors.”
- **Year and timezone:** Inject an explicit reference date, locale and calendar timezone into every request. Replace the fixed year scan with anchor-relative explicit-year detection. Preserve `yearAssumed` and add provenance for explicit, inferred or device-local timezone. Use an inferred timezone only when the flyer supports it; ask when it changes the event’s instant materially.
- **Duration and end time:** Honor explicit ranges. When the end is missing, create an editable duration suggestion based on category and explicit flyer cues. Keep the existing two-hour behavior as a labeled fallback until evaluation supports a better policy; centralize this policy so extraction and `CalendarService` do not silently use different duration assumptions.
- **Noisy notes and metadata:** Generate a short normalized summary from OCR while retaining the raw snippet and source lines. Extract age restrictions, dress code, accessibility, price, performer, venue and organizer as typed optional metadata where supported.
- **Intent and recurrence:** Return action intents such as RSVP, buy tickets, register, call or email. Associate the action with a deadline and its exact URL/contact evidence. Surface recurring-series signals as suggestions; require a user choice before creating EventKit recurrence rules.
- **Duplicate handling:** Split scan identity from event identity. Retain a stable per-asset scan key for repeat-scan recovery. Add a separate normalized event similarity key using title/date/venue and optionally local semantic comparison. Offer clusters for review; never merge or delete saved events automatically.
- **Questions and alternatives:** Ask only when the top interpretations differ in an important field, such as month/day, doors/show or two distinct event dates. Show a one-tap choice or editable alternative, then keep the full review form available.
- **Trust data:** Explain decisions with concise evidence citations and reason codes. Example: “Venue matched the line below the street address.” Keep explanations grounded in observable OCR lines; do not persist hidden chain-of-thought.

## 4. Cross-service enhancement strategy

| Service | Current responsibility | Intelligence augmentation and product value | Effect boundary |
|---|---|---|---|
| `OCRService` | On-device Vision recognition, language correction, confidence and line geometry. | Add a deterministic scan-quality report; selectively retry low-quality regions with orientation/contrast handling; group columns and nearby labels; estimate scan worthiness before Foundation Models. | OCR stays useful without model availability. Semantic grouping consumes OCR results, not a network image upload. |
| `PhotoLibraryService` | PhotoKit authorization, recent screenshot lookup, local image fetch and change stream. | Add a ranking advisor for likely flyers, “recent event candidates” and possible repeat captures. Start with the existing recent screenshot set; preserve user control and limited-library behavior. | Keep PhotoKit authorization and image reads here. Preserve `isNetworkAccessAllowed = false`. Do not scan the full library in the background without explicit opt-in. |
| `CalendarService` | EventKit authorization and create/update/delete; applies the candidate, selected calendar and alarms. | Suggest a writable calendar based on event category and the user’s past explicit choice; normalize title/location/timezone; check for likely duplicates when calendar access allows; share duration policy. | Calendar creation remains deterministic and user-triggered. Keep access-denied and write failures visible. |
| `ReminderService` | Creates or updates EventKit reminders from candidate and selected offsets. | Build an editable plan from event type, lead time, explicit RSVP deadline, urgency and user-selected preparation preferences. Distinguish a registration deadline reminder from event-start alarms. | Keep the existing offset and EventKit contract as executor. Never infer travel duration without a route source or user preference. |
| `NotificationService` | Schedules local notifications from caller-supplied copy and trigger dates; handles actions/deep links. | Select a concise template and timing from the accepted reminder plan; offer “Open event” and, with a valid supplied link, “Open RSVP/tickets.” Provide a clear saved confirmation. | Validate every trigger date and keep notification actions user-initiated. The model proposes copy; app templates constrain it. |
| `SubscriptionService` | StoreKit 2 purchases, restore and current tier (`starter`, `plus`, `premium`). | Add a feature-entitlement mapping and local usage policy for batch triage, cross-screenshot clustering, advanced reminder automation and expanded history. Explain upgrade value at the attempted feature. | Keep single-event correctness, evidence and manual review accessible. Subscription state must not change parser truth or cause silent external writes. |
| `ServiceContainer` | Constructs live/mock protocol implementations and supplies them to the UI. | Inject capability provider, interpreter, pipeline policy and optional advisors. Give tests a disabled-model implementation and deterministic scripted interpreter. | Keep runtime availability and tier policy at composition/orchestration boundaries; keep Calendar/Reminder/PhotoKit services authoritative for their permissions and side effects. |

The same pattern should be reused as service-specific advisors over shared capability, policy, evidence-validation and observability components. Calendar and Reminder write APIs should remain ordinary explicit services.

## 5. Proposed architecture pattern

Use a typed orchestration pipeline with an extraction decorator, plus narrowly scoped advisors for services that benefit from recommendations. This gives the cross-cutting capability a common home without adding an untyped AI hook to every service.

```text
Photo/image input
      │
      ▼
OCRService ──> OCRQualityReport + evidence lines
      │
      ▼
RuleBasedEventExtractor ──> deterministic findings and candidates
      │
      ├── runtime/policy gate ── unavailable or disabled ──> baseline result
      ▼
OnDeviceEventInterpreter (actor, Foundation Models)
      │ typed hypotheses with evidence references
      ▼
EvidenceValidator + CandidateRanker + QuestionSelector
      │
      ▼
EventUnderstandingResult ──> ScanViewModel ──> SwiftData + review UI
```

Recommended boundaries and protocols:

- `EventExtractionCore`: deterministic extraction from `OCRResult`, locale and an injected reference date.
- `OnDeviceEventInterpreter`: accepts a bounded `InterpretationRequest`; returns typed hypotheses. Implement the Apple adapter behind `#if canImport(FoundationModels)` and an OS availability check.
- `IntelligenceCapabilityProviding`: reports whether the local model can run now, with a typed unavailable reason. Query at use time; hardware checks alone are insufficient.
- `EventUnderstandingPipeline`: runs core extraction, applies entitlement/privacy policy, conditionally invokes interpretation, validates output and returns baseline on model unavailability or failure.
- `EventAdvisor` protocols: small service-specific recommendation contracts for photo ranking, calendar choice and reminder planning. These advisors return suggestions only.
- `IntelligencePolicy`: centralizes user setting, runtime capability, feature entitlement, rollout flag and model-cost/latency policy.

Keep `EventExtractionServiceProtocol` as an adapter during migration so existing mocks and views remain source-compatible. Add a richer value-oriented contract for `EventUnderstandingResult`; update `ScanViewModel` to carry that result through review. Materialize or update `EventCandidate` on the caller’s SwiftData context. Avoid transferring persistent models across inference boundaries.

Use Swift concurrency deliberately: isolate mutable Foundation Models session state in an actor, pass only `Sendable` value requests/results between actors, propagate task cancellation, bound OCR input and avoid concurrent unbounded sessions. Keep `ServiceContainer.live()` and `.mock()` as the composition root. Make the model provider lazy so unsupported devices do not initialize unused model state.

Observability should record stage, elapsed time, capability route, fallback reason, output-validation rejection counts and whether a user edited a field. Use privacy-aware `Logger`/signposts and never log OCR text, contact data, event titles or URLs. A debug-only review overlay can show source line IDs, selected hypothesis and validator outcomes without changing production copy.

## 6. Model and contract changes

The current `ExtractedCandidateData` is a useful `Sendable` DTO, and `EventCandidate` persists the selected event fields. Extend the value contract with the following types:

- `OCRQualityReport`: confidence distribution, text density, legibility/coverage indicators, retry status and scan-worthiness result.
- `EvidenceReference`: stable line/block identifier, source range, OCR confidence and optional bounding box. Keep evidence text on device and derive user-visible explanations from it.
- `FieldAssessment<Value>`: proposed value, provenance (`explicitText`, `deterministicRule`, `modelInterpretation`, `userEdited`), evidence references, calibrated score and ambiguity state.
- `EventInterpretationCandidate`: a full editable event hypothesis with field assessments, category, duration source, timezone source and rank. Include only a few distinct alternatives.
- `EventUnderstandingResult`: best candidate, alternatives, material ambiguity questions, action suggestions, scan quality and engine route (`rulesOnly` or `onDeviceModel`).
- `TemporalEvidence`: fragment, normalized value and role (`eventDate`, `doors`, `show`, `eventEnd`, `rsvpDeadline`, `ticketSale`, `other`).
- `ActionSuggestion`, `RecurrenceSignal`, `DuplicateCluster` and `ReminderPlan`: structured proposals with evidence, confidence and user acceptance state.

Do not use free-form model confidence as product confidence. Calibrate scores against a labeled flyer set and maintain separate OCR quality, field evidence strength and interpretation margin. Confidence UI should communicate the source and uncertainty with the design system’s icon, label and color treatment.

Persist the chosen candidate using the existing SwiftData event model. If the review must survive app relaunch with alternatives intact, add a versioned `InterpretationRecord` associated with `ScannedAsset`; store schema/engine version, alternatives, field provenance, user selection and correction outcomes. Keep raw OCR local as the current scan flow does. Do not create an independent saved event for every model hypothesis.

For dedupe, keep the current asset-bound identity useful for resume-after-rescan, and add a content-based event similarity identity for cross-asset matching. Candidate clusters should retain their source asset identifiers and require review before any merge.

## 7. Device/OS capability and fallback matrix

`Package.swift` and `project.yml` currently declare iOS 18.0. Preserve this minimum while compiling the Apple adapter with a current SDK and guarding it with `#if canImport(FoundationModels)` plus runtime availability checks.

| Runtime | Routing | User-facing behavior |
|---|---|---|
| iOS 18+ device without app-callable Foundation Models support | Vision + deterministic extraction | Full baseline scan and editable candidate; confidence/ambiguity markers remain available. |
| Apple Intelligence-compatible hardware on an OS without the Foundation Models API | Vision + deterministic extraction | Same baseline path; do not imply app-specific semantic model processing. |
| iOS 26+ and compatible device, but model is disabled, unavailable for language, not ready, or temporarily constrained | Runtime provider reports unavailable; return deterministic result | Continue scan, label it as rules-based/local OCR, and offer normal editing. |
| iOS 26+ and `SystemLanguageModel` reports availability for the request | Run local semantic pass after deterministic extraction | Show on-device enhanced interpretation, evidence and material alternatives. |
| Model generation, validation or cancellation fails | Discard invalid/partial enrichment and return the baseline result | Keep the scan open and show no generic failure if deterministic extraction succeeded. |

Compatible Apple Intelligence hardware examples include iPhone 15 Pro/Pro Max and newer supported iPhone generations, iPads with M-series chips and iPad mini with A17 Pro. Treat Apple’s runtime availability API as authoritative: support also depends on OS, language, model readiness and user/system state. The app should not reproduce an exhaustive device allowlist as its only gate.

**Fallback guarantees:** all OCR and deterministic extraction remain local and work on the iOS 18 floor; Foundation Models is optional and on-device; no remote model fallback is configured. A user setting can disable semantic interpretation. Any capability/provider error returns the baseline result. Keep rollout flags separate from StoreKit entitlement so a release experiment cannot break scanning.

## 8. UX and product implications

- **Scan entry and progress:** Keep current photo/screenshot selection and scan states. Add “Checking text,” “Interpreting event details on device” and a deterministic fallback state. Present Apple Intelligence enhancement only when the on-device model actually ran. Avoid existing generic AI branding implying model use on unsupported routes.
- **Review:** Lead with “Best interpretation,” then editable title/date/time/location. Offer compact alternate cards only for material differences. Choosing an alternative updates the editable draft; it does not save a second event.
- **Confidence and ambiguity:** Use accessible labels such as “Confirmed from flyer,” “Inferred,” and “Please check,” alongside the design system’s icon and color. Keep touch targets at least 44 points. Make date locale ambiguity and assumed year explicit.
- **Evidence:** Add a collapsible “Why this?” section showing the source phrase and concise reason: “Show time selected from the line marked ‘Show’; doors at 7:00 PM kept in notes.” Keep explanations short and evidence-linked.
- **Follow-up questions:** Ask only when competing interpretations produce materially different events. Make answers inline and one tap; preserve a manual edit path.
- **Actions and reminders:** Present RSVP/ticket/registration as a checklist with deadline and link. Show a suggested reminder schedule with editable offsets and a reason. Require the user to tap the link or accept a reminder plan.
- **Duplicate handling:** In the scan result, say “This may match an event already saved” and offer open, compare or keep separate. In archive history, group likely duplicate screenshots without deleting source scans.
- **Archive triage:** Add filters for needs-review, upcoming, RSVP deadline, possible duplicate and recurring series. Keep evidence and source asset available for correction.
- **Subscriptions:** Keep baseline extraction, evidence and manual review available to Starter users. Use Plus for enhanced screenshot/photo triage consistent with its current tier positioning. Use Premium for batch scan automation, larger archive clustering and advanced reminder plans. Show runtime availability separately from plan entitlement; an unsupported device should not be sold a model capability it cannot run.
- **Trust and privacy:** State when interpretation ran locally, when a field is inferred and which values came from visible text. Preserve user edits as the source of truth. Do not auto-commit Calendar, Reminders, external links or RSVP actions.

Follow the design tokens and component patterns in [`datesnap-design-system-updated.md`](../../datesnap-design-system-updated.md).

## 9. Phased implementation roadmap

### Phase 0 — Architecture foundation

- **Goals:** Define capability routing, stable value contracts, evidence references, policy/entitlement seams and baseline fallback before adding model behavior. Confirm runtime wiring through `ContentView`, `HomeEmptyStateView`, `ScanFlowViews` and `EventReviewEditView`.
- **Likely files:** `Services/EventExtractionService.swift`, `Services/ServiceContainer.swift`, `Services/OCRService.swift`, `ViewModels/ScanViewModel.swift`, `Models/SwiftDataEntities.swift`, `Package.swift`, `project.yml`.
- **New files:** `Services/Intelligence/IntelligenceCapabilities.swift`, `IntelligencePolicy.swift`, `EventUnderstandingModels.swift`, `EventUnderstandingPipeline.swift`, `EvidenceValidator.swift`; mock capability/interpreter implementations in test support.
- **Risks:** Source compatibility, `Sendable` boundaries, persistence migration and SDK availability. Fallback: keep current extraction protocol as an adapter and leave the interpreter disabled by default.
- **Acceptance:** Existing iOS 18 deterministic scan remains operational through the current view path; mocks compile against the new seams; model-unavailable mode produces the existing candidate behavior; no SwiftData model is passed into the model actor.

### Phase 1 — Apple Intelligence extraction augmentation

- **Goals:** Add the Foundation Models adapter, constrained event schema, evidence-grounded alternatives and ambiguity question selector. Improve role labeling, temporal association, RSVP intent, category, notes and duration suggestions.
- **Likely files:** New `Services/Intelligence/AppleFoundationModelInterpreter.swift`; `EventExtractionService.swift`; `ScanViewModel.swift`; `EventReviewViewModel.swift`; review UI in `EventReviewEditView.swift` and `EventReviewForm`.
- **Risks:** Hallucinated associations, session limits, language readiness, latency and battery. Fallback: use the validated rule result on any unavailability, failure or invalid output.
- **Acceptance:** Every accepted model value points to valid evidence or an explicitly labeled contextual inference; invalid dates/URLs are rejected; unsupported devices continue normally; material alternatives remain editable; no unconfirmed hypothesis is written to Calendar or Reminders. Evaluate on a labeled set covering stylized flyers, multiple events, doors/show, deadlines, locale ambiguity and OCR noise.

### Phase 2 — Cross-service enhancement rollout

- **Goals:** Add scan-worthiness and photo ranking; introduce separate event similarity clusters; provide calendar recommendations and reminder plans; improve notification templates and action routing.
- **Likely files:** `OCRService.swift`, `PhotoLibraryService.swift`, `CalendarService.swift`, `ReminderService.swift`, `NotificationService.swift`, `ServiceContainer.swift`, `HomeViewModel.swift`, `EventReviewViewModel.swift`, `SubscriptionService.swift`.
- **New files:** `PhotoCandidateRanker.swift`, `EventSimilarityService.swift`, `CalendarRecommendationService.swift`, `ReminderStrategyService.swift`, `FeatureEntitlements.swift`.
- **Risks:** Permission overreach, incorrect duplicate merges, stale user preferences and StoreKit/offline entitlement state. Fallback: deterministic ranking and current explicit service calls; duplicate matches remain suggestions.
- **Acceptance:** Photo permission scope is unchanged; image fetch stays local; EventKit writes still require user save; reminder recommendations never exceed app-supported offsets; duplicate clusters preserve independent records; failure in any advisor leaves its underlying service usable.

### Phase 3 — UX and product integration

- **Goals:** Integrate scan quality, best interpretation, alternatives, field provenance, material questions, action suggestions, reminder edits and duplicate review into the live SwiftUI flows.
- **Likely files:** `Views/HomeEmptyStateView.swift`, `Views/ScanFlowViews.swift`, `Views/EventReviewEditView.swift`, `Views/ReviewQueueView.swift`, `Views/HistoryArchiveView.swift`, `ViewModels/ScanViewModel.swift`, `ViewModels/EventReviewViewModel.swift`, design system components.
- **Risks:** Review complexity, accessibility regressions and model branding that overstates availability. Fallback: render a single editable deterministic candidate with the same review form and clear assumptions.
- **Acceptance:** Best/alternate selection edits one candidate; explanations identify source evidence; ambiguous states include icon, text and color; controls meet 44-point minimum; users can complete scan, manual correction and save without model availability.

### Phase 4 — Evaluation, tuning and premiumization

- **Goals:** Calibrate scores and question thresholds, evaluate model quality across supported languages/devices, tune latency and introduce transparent feature entitlements for automation.
- **Likely files:** `Tests/DateSnapTests/`, `SubscriptionService.swift`, `ServiceContainer.swift`, `SettingsState.swift`, paywall and archive views; add a local evaluation harness and sanitized fixtures.
- **New files:** Extraction evaluation fixtures/reporting, `IntelligenceUsagePolicy.swift`, optional debug diagnostics view.
- **Risks:** Overfitting to English concert posters, Apple API changes, premium gating perceived as blocking correctness and accidental content logging. Fallback: ship core interpretation behind a runtime/remote-free local feature flag; keep tier-based automation disabled until evaluation gates pass.
- **Acceptance:** Report field-level precision/recall, doors/show accuracy, question precision, duplicate false-merge rate, latency and fallback rate by capability route. Set release thresholds from the hand-labeled baseline before rollout. Verify no OCR text or event PII enters telemetry. Keep single-scan review available across tiers and gate only clearly explained convenience/automation.

## 10. Risks, tradeoffs and open questions

- **Semantic overreach:** A language model may make a coherent but unsupported guess. Constrain output to known evidence, validate every field and preserve uncertainty. Keep deterministic high-confidence findings authoritative.
- **Confidence quality:** A model’s numeric self-assessment is not calibrated. Use measured field reliability and top-candidate margin; tune on representative flyers before showing precise percentages.
- **Language and visual diversity:** Stylized fonts, low contrast, multilingual flyers and cultural date formats need a curated evaluation corpus. Expand language support only after the OCR and model route are measured for that language.
- **OS/API changes:** The app’s iOS 18 minimum is older than the Foundation Models API. Guard imports and calls, test the supported OS path, and keep release compilation on the deployment floor.
- **Latency and resource use:** Run only after a cheap deterministic gate, bound input size and limit retries. A canceled or slow model pass must not block baseline scan completion.
- **Persistence shape:** Alternatives and provenance need a schema/version strategy. Keep the current scalar `EventCandidate` record canonical; add a separate versioned interpretation record only when durable review restoration requires it.
- **Privacy and consent:** Keep model requests, OCR evidence and correction history on device. Do not send flyer text to a server for analytics or use a user’s Calendar contents as personalization without a clear permission and product decision.
- **Subscription boundary:** Decide whether supported-device single-scan semantic assistance is included for all tiers. Recommendation: include it as a review-quality capability; charge for batch automation, large-scale triage and advanced convenience features.
- **Personalization policy:** Decide whether user corrections should tune only local ranking, be exportable/deletable, and persist across reinstall through user-controlled backup.
- **Recurrence semantics:** Decide whether repeated dates on a flyer represent multiple event candidates or a single recurring EventKit event; preserve the distinction in UI and require explicit confirmation.
- **Language rollout:** Choose the initial supported locales for date extraction, semantic interpretation and localized explanation copy; the runtime model’s supported language set should determine the available route.
