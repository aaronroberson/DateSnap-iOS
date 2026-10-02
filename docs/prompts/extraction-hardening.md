# Prompt: OCR + Event Extraction Hardening

You are a Principal iOS Architect specializing in Swift 6 language mode, SwiftUI, Vision/NaturalLanguage/EventKit, and on-device ML pipelines. Your task is to **evolve the existing protocol-driven service layer of "DateSnap"** — a privacy-first iOS app that scans screenshots/photos locally and creates Apple Calendar events, Reminders, and local notifications — by hardening `OCRService` and rebuilding `EventExtractionService` into a production-grade date-inference engine.

**This code already exists. Do not rewrite from scratch — extend, refactor, and complete it.**

## 0. REQUIRED READING (ground every change in these files)

| File | What's there / why it matters |
|---|---|
| `Package.swift` | swift-tools **6.4**, platform **`.iOS(.v18)`**, upcoming feature `ApproachableConcurrency`. Your concurrency style must match this, not Swift 5.9. |
| `AGENTS.md` | Build commands, design-doc mandate, layout rules. |
| `datesnap-design-system-updated.md` | Mandatory for any UI you touch. Confidence tiers must use `--color-success #46E39A` / `--color-warning #FFBE55` / `--color-error #FF6B7A`, and the Accessibility section requires **icon + label + color**, never color alone. |
| `Sources/DateSnap/Services/OCRService.swift` | `OCRServiceProtocol` (:6-8) + `OCRService` (:11-65). Runs `VNRecognizeTextRequest` in `Task.detached`. **Discards `boundingBox` metadata** — this blocks visual-hierarchy title inference. |
| `Sources/DateSnap/Services/EventExtractionService.swift` | `EventExtractionServiceProtocol` (:62-64), DTO→model bridging (:5-59, :112-113), single-date parse engine (:124-318), naive confidence sum (:85-93), title/location/URL extractors (:321-397). Returns **at most 1 candidate** (:109). |
| `Sources/DateSnap/Services/ServiceContainer.swift` | Production DI hub and environment integration. The app target intentionally contains no mock service implementations; add protocol-specific test doubles only under `Tests/DateSnapTests` when tests require them. |
| `Sources/DateSnap/Services/DateSnapError.swift` | Domain errors already defined. `ExtractionError.ambiguousDateResolutionFailed` (:120) and `OCRError.insufficientConfidence` (:90) exist but are **never thrown** — wire them up. |
| `Sources/DateSnap/Persistence/SwiftDataEntities.swift` | `ScannedAsset.candidates` cascade relationship (:57-58), `EventCandidate` (:81-128) — note **no dedupe key, no per-field confidences, no ambiguity flag, no timezone field yet**. `SavedEvent` (:131-165). |
| `Sources/DateSnap/ViewModels/ScanViewModel.swift` | The 3-stage pipeline `fetchingImage → processingOCR → extractingEvents → complete/noDatesFound/failed` (:13-36) and persistence step (:96-112). |
| `Sources/DateSnap/ViewModels/EventReviewViewModel.swift` | Review/commit flow; already surfaces `yearAssumed` (:54) and caps reminders at 3 offsets (:102-110). |
| `Sources/DateSnap/Models/SettingsState.swift` | `confidence` threshold (default 85, :70) and `draftLowConfidence` (:71) — extraction output must be consumable by these gates. |
| `Sources/DateSnap/Views/HelpFeedbackView.swift` | Product promises to the user: relative dates ("Tomorrow 10am"), ambiguous dates are **prompted, not guessed** (:32), confidence threshold gating (:45). |
| `Sources/DateSnap/Views/EventReviewEditView.swift`, `NoDatesFoundView.swift` | Where ambiguity review and empty states render. |

Verify with: `xcodebuild -scheme DateSnap -destination 'platform=iOS Simulator,name=iPhone 16' build`

## 1. HARD CONSTRAINTS

- **Platform/toolchain:** iOS 18+, Swift 6.4 + `ApproachableConcurrency`. Sendable-correct; no `@unchecked Sendable` escapes beyond what already exists.
- **Privacy rule:** zero network calls (`URLSession`, `URLCache`, telemetry) anywhere in the target. `NSDataDetector`, Vision, NaturalLanguage, and `NSTimeZone` only.
- **Protocol stability:** keep the signatures at `OCRServiceProtocol` (`OCRService.swift:7`) and `EventExtractionServiceProtocol` (`EventExtractionService.swift:63`) source-compatible for existing production callers. Add new capabilities via **protocol extensions with default implementations** or additive protocol requirements, then update any test-target doubles that exist.
- **SwiftData safety:** `@Model` instances (`EventCandidate`, `ScannedAsset`) must only be constructed/inserted on the MainActor caller's context. Keep the existing DTO pattern (`ExtractedCandidateData`, `EventExtractionService.swift:5-59`) — run heavy parsing in `Task.detached`, map to models after.
- **Schema changes are additive-only** (new fields with defaults) so existing stores migrate.
- **Errors:** throw `DateSnapError` / `OCRError` / `ExtractionError` — never raw strings.
- **Comment style:** `// MARK: -` section headers and doc comments only; no line-by-line narration.
- **UI:** any new view/banner must follow `datesnap-design-system-updated.md` (glass surfaces, semantic tokens, 44pt targets).

## 2. WORKSTREAM A — OCRService: structured OCR with layout metadata

Keep `recognizeText(in:)` exactly as-is, but add an additive capability (e.g. `func recognizeLines(in:) async throws -> OCRResult`) where `OCRResult` is a Sendable struct carrying `lines: [OCRLine]`, `fullText`, `meanConfidence`. Each `OCRLine` carries `text`, `confidence`, `boundingBox: CGRect` (Vision-normalized), and derived metrics.

1. Populate from `VNRecognizedTextObservation.boundingBox` — currently thrown away at `OCRService.swift:44-53`.
2. Sort lines top-to-bottom using `boundingBox.maxY`, preserving reading order; join with `\n`.
3. Compute a **font-size proxy** = `boundingBox.height / CGFloat(text.count)` per line — this feeds title inference in Workstream B.
4. Keep `recognitionLevel = .accurate`, `usesLanguageCorrection = true`, `automaticallyDetectsLanguage = true`, off-main via `Task.detached`.
5. Throw `OCRError.insufficientConfidence(score)` when mean confidence falls below the caller-supplied floor (default ~0.35), so `ScanViewModel` can surface the existing recovery copy.

## 3. WORKSTREAM B — EventExtractionService: advanced date-inference algorithms

Implement these as clearly separated, individually testable static/pure functions inside `EventExtractionService` (or a dedicated `DateInference` namespace). The pipeline is a **detector cascade → resolver stage → segmenter → scorer → deduper**.

### B1. Detector cascade (candidate spans, not just first match)
Today only `matches.first` is used (`EventExtractionService.swift:134`). Run all four detectors over the full text and keep **every** match with its `NSRange`:

1. `NSDataDetector(.date)` — baseline.
2. Month-name regex (`EventExtractionService.swift:155-160`) — extend to capture ordinal suffixes, weekday prefixes (`Mon, Oct 12`), and **ranges** (`Oct 12–14`, `December 1-3, 2026`).
3. Numeric regex (`:185`) — as today, but retain match count and separators.
4. **Relative-phrase lexicon** (new): `today|tonight|tomorrow|tmrw|next|this|coming|last|in N days?|week|month`, weekday names, `noon|midnight|midday|eod|TBA`.

Dedupe overlapping spans by keeping the longest/highest-priority match (relative > month-name > numeric > detector).

### B2. Locale-aware numeric disambiguation (`12/10/2026` vs `10.12.26`)
- Resolve deterministically when one component `> 12` (as today, `:201-206`).
- When **both ≤ 12**, resolve using `Locale` (`locale.identifier`, `locale.region?.identifier`, `Calendar.current` locale conventions). If the locale itself is ambiguous (e.g. `en_001`), **do not guess**: emit the candidate with `isAmbiguousDate = true` and `ambiguousFragment` populated, and surface it in `EventReviewEditView` as a month/day toggle — per the product promise at `HelpFeedbackView.swift:32`. `ExtractionError.ambiguousDateResolutionFailed` is the error fallback when strict mode is requested.

### B3. Relative-date resolver
Normalize against `Calendar.current` with an explicit **anchor `Date`** injected as a parameter (never call `Date()` deep in logic — makes tests deterministic):

- `today`/`tonight` → anchor day; `tonight` biases hour ≥ 18.
- `tomorrow` / `in N days` → `calendar.date(byAdding:.day, value: N, to: anchor)`.
- `this/coming <weekday>` → next occurrence within the next 7 days: `daysAhead = (target - anchorWeekday + 7) % 7`, `== 0 → 7`.
- `next <weekday>` → strictly the following week: `daysAhead + 7` (state this convention in a doc comment).
- `next week` / `in 2 weeks` → `byAdding:.weekOfYear`.

### B4. "Assumed Year" chronological inference
Generalize the logic at `:252-310` into one function:

- No explicit year → build `(year: currentYear, month, day, hour, minute)`; if result `< anchor`, use `currentYear + 1`; set `yearAssumed = true`.
- **Validate the composed date**: if `calendar.date(from:)` returns nil (Feb 29 in a non-leap year), roll forward to the next valid Feb 29 or clamp to Feb 28 — never silently emit `Date()`.
- Past explicit dates with no year token anywhere in text: keep the existing +1 year roll (`:298-310`) but only when the detector's match lacks a year **and** the text has no 4-digit year — extract that into a named helper.

### B5. Multi-date candidate array (festival lineups / ranges)
Replace the single-candidate return (`:109`) with a **block segmenter**:

- Split text into lines; group consecutive lines into event blocks (blank-line gap, or a new date-match starts a block).
- For date **ranges**, expand to one candidate per day (bounded, e.g. ≤ 14 days) — these are selectable `EventCandidate` rows, all children of the same `ScannedAsset` (relationship already exists at `SwiftDataEntities.swift:57-58`). Do **not** invent a new entity unless you also migrate the review UI.
- Multi-day schedules: one candidate per distinct date, shared title/venue, each independently reviewable — matches `ScanViewModel`'s `[EventCandidate]` stage payload.

### B6. Time parsing, windows, and multi-marker disambiguation
- Extend the window regex (`:224`) to handle `– — - to until` separators, `7PM-11:30PM`, 24-hour times, and `noon/midnight`.
- **Doors vs. show:** when ≥ 2 distinct times attach to the same date, take the **earliest** as start and **latest** as end; retain all raw markers in `rawTextSnippet`.
- **Meridiem inference** when absent: hour `1–6` → PM (event context), `7–11` → PM, `12` → PM, `0`/`00` → midnight; record `meridiemAssumed` in confidence math.
- **Overnight:** end `<` start on the same day → end `+1 day` (existing partial logic at `:289`).
- **All-day fallback:** no time token anywhere → `isAllDay = true`, start at `00:00`, `endDate = nil`; keep the time picker reachable in review (already true via `EventReviewViewModel:47`).

### B7. Timezone metadata
Regex `\b(PST|PDT|EST|EDT|CST|CDT|MST|MDT|GMT|UTC|BST|CET|IST)\b`; reverse-lookup via `NSTimeZone.abbreviationDictionary` to store a `timeZoneIdentifier` on the candidate (additive field) so travel-time accuracy is preserved when writing `EKEvent`. Absent → `Calendar.current.timeZone`.

### B8. Visual-hierarchy title inference (uses Workstream A's boxes)
Replace the line-prefix heuristic (`:321-343`) with a scored choice over `OCRLine`s:

- Score = `0.45·normalizedBoxWidth + 0.30·fontProxyRank + 0.15·topQuartileBonus − 0.10·boilerplatePenalty`, where boilerplate = existing keyword list (`:326-330`) plus phone/URL/date/price-only lines and lines matching the date span.
- Highest-scoring line in the upper 60% of the image becomes the title; if the protocol wasn't upgraded, fall back to the current heuristic (graceful degradation).
- **Field isolation:** from the remaining lines, extract address (existing regex `:347`), venue (line above address, or venue keyword), RSVP URL (`NSDataDetector(.link)`, existing `:381-397`), phone (`\+?[\d().\s-]{7,}`), and email — each into its own candidate field.

### B9. Multi-dimensional confidence scoring
Refactor the flat sum (`:85-93`) into independent, documented scores:

- `dateConfidence` = f(source reliability: detector 0.95 / month-name 0.9 / numeric-locale-resolved 0.8 / numeric-ambiguous 0.5 / relative 0.92) × (explicit year ? 1.0 : 0.92) × (ambiguous fragment ? 0.7 : 1.0).
- `titleConfidence` = f(B8 score, keyword penalties).
- `overallConfidence` = weighted geometric mean (not arithmetic — a single weak field should drag the total), then clamp to `[0.40, 0.99]`.
- **Tiers:** `≥0.90 High`, `0.70–0.89 Medium`, `<0.70 Low` → map to `--color-success/warning/error` **with icon + label** per design-doc accessibility rules; the existing mapping at `SwiftDataEntities.swift:203` (`> 0.9 High AI Accuracy`) should read from the tier, not a magic number.
- Persist `dateConfidence`/`titleConfidence`/`tier` as additive fields on `EventCandidate`, or derive them in a single `ConfidenceBreakdown` struct if you want zero schema churn — pick one and justify it.

### B10. False-positive filtering
Reject (or hard-penalize to Low tier) text blocks that:

- contain no date signal from any B1 detector (existing guard `:81-83`, keep);
- look like **receipts** (`\$\d+\.\d{2}`, `SUBTOTAL|TOTAL|TAX`, ≥ 3 price tokens), **order/shipping notifications** (`order #`, `delivered`, `tracking`), or **phone-number-only** OCR;
- resolve to a date **> 24 months in the past** with no explicit 4-digit year, or > 5 years ahead;
- match a pure-timestamp screenshot pattern (`\d{2}:\d{2}(:\d{2})?` lines with no month/weekday).

Rejected blocks must not appear in `extractedCandidates`; if **everything** is rejected, return `[]` so `ScanViewModel` shows `.noDatesFound` (`ScanViewModel.swift:117-118`) — that view already exists.

### B11. Normalized multi-field deduplication
- Compute `dedupeKey = fnv1a64(normalize(title) + "|" + startTimeRoundedToMinute + "|" + normalize(venue ?? location) + "|" + assetIdentifier)` where `normalize` = lowercase, strip diacritics, collapse whitespace, drop punctuation, and remove stop-words (`the|a|presents`).
- Persist as an additive field on `EventCandidate` (indexed, not unique across assets).
- Before inserting in `ScanViewModel.scanImage` (`:96-112`), fetch existing candidates with the same key **excluding the current asset** and drop matches — prevents duplicate calendar entries/repeat notifications when the same screenshot is scanned twice (the `SavedEvent.scheduledNotificationIds` path at `EventReviewViewModel.swift:166-179` is where the duplicate would otherwise fire).

## 4. WORKSTREAM C — Wiring end-to-end

1. `ScanViewModel.scanImage` stays the orchestrator; if you add `recognizeLines`, route OCR → extraction with line metadata passed through (extend the extraction entry point additively, e.g. `extractCandidates(from: OCRResult, locale: Locale)`, with a default implementation that flattens to text so the old signature still works).
2. Persist `ScannedAsset.rawOcrText/ocrConfidence/candidateCount` as today; set `candidateCount` to the **post-dedup** count.
3. `EventReviewViewModel`: surface `yearAssumed` (already a published property) and the new ambiguity/tier fields; if `isAmbiguousDate`, present the month/day swap control **before** `commitEvent` is enabled.
4. Honor `SettingsState.confidence` (85) and `draftLowConfidence` as the gate between auto-commit and review-tray — extraction must return the raw score, the VM applies the threshold.
5. Keep `ServiceContainer.live()`/`.mock()` the single composition root; no service may instantiate another service directly.

## 5. ACCEPTANCE CRITERIA

- `xcodebuild -scheme DateSnap -destination 'platform=iOS Simulator,name=iPhone 16' build` passes with zero warnings introduced by your changes.
- Production sources contain no mock service implementations or `ServiceContainer.mock()` factory. Any test-target doubles and previews explicitly inject all required dependencies and compile.
- New parsing logic is pure and deterministic (anchor date injected) and covered by a new `DateSnapTests` test target in `Package.swift` with fixtures for: relative dates, ambiguous numerics in `en_US`/`en_GB`/`de_DE`, assumed-year rollover incl. Feb 29, date ranges, doors/show windows, receipt false-positives, and dedupe key stability.
- Grep-verified: no `URLSession`, `http`, or third-party imports added under `Sources/`.
- Every new user-visible state has icon + label + color (design doc, Accessibility section).
