# Pencild iOS — Launch Monetization & Packaging Strategy

*Prepared October 2026 · Based on current App Store competitor pricing, RevenueCat 2026 benchmarks, and Adapty trial conversion data*

---

## Decision Record: Plans, Limits, and Paywalls (2026-10-13)

**Status:** Implemented as intended design. Supersedes conflicting
recommendations below (7 free scans, 30-day history, images-only free tier,
one shared comparison paywall, 90-day lifetime window), which are kept as the
original research. Evidence: `docs/audits/2026-10-11-production-readiness-audit.md`
§7.6, §7.8, §7.9, §7.11, and §7.12.

**Plans and prices** (StoreKit `Product` prices; `Pencild.storekit` values shown):

| Plan | Monthly | Annual | Lifetime (intro offer) |
|---|---|---|---|
| Plus | $3.99 | $24.99 | $39.99 |
| Premium | $6.99 | $39.99 | $79.99 |

- Monthly and annual plans carry a 1-week free trial. Annual is selected by
  default on the paywall.
- Lifetime is a non-consumable, offered for Plus and Premium through
  2027-04-13, with the end date enforced in the app (`LifetimeIntroOffer`).

**Free plan:**
- 10 scans per month. Only scans that find a new event count, so rescanning
  an unsaved flyer doesn't use a scan. Resets on the 1st.
- 1 alert per event (paid plans: 3).
- No history limit.
- Paid plans: unlimited scans.

**Feature tiers** (`PremiumFeature`):
- **Plus:** automatic screenshot detection, likely-event triage.
- **Premium:** PDF and file import, duplicate clusters, tailored reminder plans
  and RSVP-deadline reminders, work schedules and multi-date flyers.

**Paywall rules:**
- **Paid controls stay visible to everyone.** Using one without the
  entitlement opens the paywall instead of running the operation. Paid
  controls are never hidden or removed.
- **Paid results are never revealed without the entitlement.** For example,
  the tailored-alerts row opens the paywall without showing the suggested
  plan, and a detected work schedule creates no events and uses no free scan.
- **Batches never skip items silently.** If a selection is bigger than the
  free scans left, the user chooses to deselect, upgrade, or discard before
  anything is scanned. An item that needs a higher plan is flagged in Batch
  Review with an upgrade row.
- **Subscribers are never blocked by a slow entitlement check.** While
  StoreKit is still checking, limits and gated features are allowed.
- **Paywalls are interstitials.** Separate Plus and Premium sheets can open
  from anywhere, with a close button at the top right and an "Upgrade to …"
  headline. Restore Purchases is in the paywall body, not the top bar, by
  design.

---

## Executive Recommendation

> **Superseded 2026-10-13:** the free tier (7 scans, images only, 30-day history), the shared comparison paywall, and the $59.99/$99.99 90-day lifetime below are original research. See the Decision Record at the top of this document for what shipped.


- **Three-tier model: Free / Pencild Plus / Pencild Premium.** Free limits by scan volume and file type; Plus serves everyday screenshot/flyer users; Premium serves PDF and document-heavy workflows.
- **Plus pricing: $3.99/month or $24.99/year** (~$2.08/mo annualized, 48% savings). Competitive with and above direct image-to-calendar competitors while being clearly affordable for individual users.
- **Premium pricing: $6.99/month or $39.99/year** (~$3.33/mo annualized, 52% savings). Positioned between direct competitors and OCR/document scanning apps (Genius Scan $39.99/yr, PDF Expert ~$49.99/yr). The existing $8.99/month concept is above launch evidence — reduce it.
- **Free tier: 7 scans/month, images/screenshots only, single reminder, 30-day history.** This is enough to demonstrate the core "scan → review → save" loop without making the app feel broken.
- **7-day free trial on Plus and Premium.** Industry data shows 7-day trials outperform 3-day trials on Day-0 cancellation (40% vs. 55%) and give users time to complete 2–3 real import workflows before the decision point.
- **Annual plan as default selection** on the paywall. Annual-dominant apps earn approximately 2× the revenue per install of monthly-dominant apps at Day 60 (RevenueCat 2026).
- **One shared comparison paywall** showing Free / Plus / Premium side-by-side. Separate paywalls add friction; a comparison table at the right moment converts better for a multi-tier utility.
- **Lifetime pricing as a limited-time launch promotion only.** Offer Plus Lifetime at $59.99 and Premium Lifetime at $99.99 for the first 90 days post-launch. Do not make lifetime permanent at launch. Re-evaluate at Day 90.

---

## Capability Inventory

| Capability | Status | Recommended Tier | Notes / Rationale |
|---|---|---|---|
| Scan images/screenshots from Photos | **Existing** | Free (limited) + Plus (unlimited) | Core "aha" moment — must be in Free, but limit volume to create upgrade pressure |
| OCR and date/event extraction | **Existing** | Free (limited) + Plus | Core magic; degraded limit in Free is fine, full access in Plus |
| Review, edit, validate before saving | **Existing** | Free + Plus + Premium | Never gate this; gating review = broken product |
| Save to Apple Calendar | **Existing** | Free (limited) + Plus | Allow ≤3 saves/scan session in Free; unlimited in Plus. Do NOT fully remove from Free |
| Single reminder / notification | **Existing** | Free | Basic reminder keeps Free feeling functional |
| Multi-stage reminder schedules | **Existing** | Plus | Clear upgrade incentive; 2–3 reminders/event per scan |
| Files/PDF document import | **Existing** | Premium | Requires iCloud/Files permission; clear power-user gating |
| Multi-page PDF scanning | **Existing** | Premium | High differentiation vs. direct competitors |
| Batch scanning (multiple docs) | **Existing** | Premium | Significant time value; strong justification for tier |
| Scan history/archive | **Existing** | Free (30 days) → Plus (90 days) → Premium (unlimited) | Graduated depth creates natural upgrade path |
| On-device intelligence/OCR | **Existing** | All tiers | Core feature; do not gate |
| Subscription entitlement controls | **Existing** | Infrastructure | Already implemented |
| Advanced calendar rules | **Existing (planned)** | Premium | Auto-routing events to specific calendars; power-user feature |
| Smart event discovery from Photos | **Proposed** | Premium (post-launch) | High user value; requires background access and index; App Review risk if not scoped correctly |
| Event triage/ranking from screenshots | **Proposed** | Premium (post-launch) | Incremental on top of smart discovery |
| Recurring scan routines / automation | **Proposed** | Premium (post-launch) | Requires App Intents or Background Tasks; feasible but not launch scope |
| Calendar color/category rules | **Proposed** | Premium | Small quality-of-life feature; group with advanced calendar rules |
| Location/geofence reminders | **Proposed** | Premium (post-launch) | Requires Always-On Location permission; notable App Review/user trust risk; flag before shipping |
| Family/household sharing | **Proposed** | TBD (post-launch) | Requires Family Sharing entitlement; adds support complexity |
| Event conflict detection | **Proposed** | Plus or Premium (post-launch) | Requires Calendar read access; medium App Review consideration |
| AI event-planning suggestions | **Proposed** | Premium (post-launch) | Requires cloud inference; adds per-user cost; do not include at launch |
| Export/share formats (.ics, etc.) | **Proposed** | Plus (post-launch) | Low implementation cost; good Plus retention feature |
| Custom reminder templates | **Proposed** | Plus (post-launch) | Low risk, good Plus stickiness |
| Cross-device sync/backup | **Proposed** | Premium (post-launch) | Requires iCloud or backend; significant infrastructure; do not launch scope |
| Widgets, Shortcuts, App Intents | **Proposed** | Plus / Premium | Shortcuts is low risk and high perceived value; good post-launch Plus add |
| Dropbox/Google Drive integration | **Proposed** | Premium (post-launch) | Requires OAuth flows and third-party entitlements; post-launch |

---

## Recommended Plans

> **Superseded 2026-10-13:** monthly and annual prices below still match; lifetime ($39.99/$79.99 through 2027-04-13), the free-plan limits, and the history rows do not. See the Decision Record at the top of this document for what shipped.


| Feature | 🆓 Free | ⭐ Pencild Plus | 💎 Pencild Premium |
|---|---|---|---|
| **Monthly price** | $0 | $3.99 | $6.99 |
| **Annual price** | $0 | $24.99/yr (~$2.08/mo) | $39.99/yr (~$3.33/mo) |
| **Annual savings vs. monthly** | — | 48% | 52% |
| **Lifetime (launch promo only)** | — | $59.99 | $99.99 |
| **Free trial** | N/A | 7 days | 7 days |
| **Image/screenshot scan limit** | 7/month | Unlimited | Unlimited |
| **PDF / Files import** | ✗ | ✗ | ✓ |
| **Multi-page PDF support** | ✗ | ✗ | ✓ |
| **Batch scanning** | ✗ | ✗ | ✓ (up to 10 docs/batch) |
| **Review & edit before save** | ✓ | ✓ | ✓ |
| **Save to Apple Calendar** | ✓ (up to 3/session) | ✓ Unlimited | ✓ Unlimited |
| **Reminders / notifications** | 1 per event | Multi-stage (up to 3) | Multi-stage (up to 3) |
| **Scan history / archive** | 30 days | 90 days | Unlimited |
| **Advanced calendar rules** | ✗ | ✗ | ✓ |
| **On-device OCR / intelligence** | ✓ | ✓ | ✓ |
| **App support** | Community / self-help | Standard email support | Priority support |
| **Early access to new features** | ✗ | ✗ | ✓ |

**Tier design rationale:**
- Free demonstrates the magic (scan → review → save) within understandable limits. 7 scans/month equals roughly one event per week, which is a real use case without giving away everything.
- Plus serves the core individual: someone who regularly imports event flyers, screenshots, and tickets. Unlimited scans + multi-stage reminders + Calendar sync is a complete, polished experience.
- Premium serves power users: parents with tournament schedules, event coordinators, admins managing multi-page agendas. PDF + batch + unlimited archive justifies a meaningful price step.

---

## Pricing Architecture

### Monthly Prices
- **Plus $3.99/mo** — above the cheapest direct competitor (Calendarco $1.99/mo) and below EventScan ($4.99/mo). Positions Pencild as more polished without being expensive.
- **Premium $6.99/mo** — meaningfully above Plus, well below Adobe Scan Pro ($9.99/mo), and roughly aligned with productivity subscription psychology for a specialized workflow tool.

### Annual Prices
- **Plus $24.99/yr** — monthly equivalent of $2.08. Annual savings of 48%. Annual plans should be the default paywall selection. RevenueCat 2026 data shows annual-dominant apps earn 2× revenue per install vs. monthly-dominant apps.
- **Premium $39.99/yr** — monthly equivalent of $3.33. Annual savings of 52%. Aligns with Genius Scan Ultra ($39.99/yr) as a reference point for power-user document utilities.
- Show the monthly equivalent on all annual plan displays (e.g., "Just $2.08/month").

### Lifetime Pricing (Launch Promotion Only — 90 days)

> **Superseded 2026-10-13:** lifetime shipped at $39.99 (Plus) and $79.99 (Premium), offered through 2027-04-13. See the Decision Record at the top of this document for what shipped.

- **Plus Lifetime: $59.99** — approximately 2.4× annual price; 15× monthly. Positioned as the obvious "never pay again" deal for early adopters.
- **Premium Lifetime: $99.99** — approximately 2.5× annual price; 14.3× monthly. Strong early-adopter signal, manageable CAC recovery.
- **Do not make lifetime permanent.** RevenueCat data shows lifetime offers work best as limited-time promotions. Permanent lifetime pricing cannibalizes high-LTV subscribers and is unattractive to investors. After 90 days, withdraw the offer and re-evaluate at Day 180 if churn data warrants a second promotion.
- **Implementation note:** Lifetime on iOS is a non-consumable in-app purchase (not a subscription), so it cannot carry the standard 7-day trial. Disclose this on the paywall where lifetime is presented.

### Free Trial
- **7 days on both Plus and Premium.** Industry sweet spot per Adapty (5–9 days: 37–45% median conversion). 7 days gives users time to complete 2–4 real scan-and-save workflows before the subscription activates.
- **On iOS, trials are opt-out by default** (StoreKit manages billing; users must actively cancel). This means trial start is relatively easy; focus energy on delivering value in the first 2 days.
- ~40% of 7-day trial users cancel on Day 0 (higher intent than 3-day trials, which see 55% Day-0 cancellation). Send a reminder notification on Day 5 ("Your free trial ends in 2 days").
- Do NOT require a credit card above and beyond what Apple already requires. iOS trials are handled by StoreKit — Apple shows the billing information during the subscription initiation, which is appropriate transparency.

### Introductory Offer (Launch)
- For the first 90 days: display a "Launch Special" banner on the paywall. Frame it as a time-limited discount of 30% off the first year for annual plans (effective: Plus annual $17.49, Premium annual $27.99).
- This creates urgency without undermining long-term pricing. After the promotion ends, the standard prices restore automatically via App Store promotional pricing.
- **Framing:** "Launch offer — 30% off your first year. Ends [date]." No countdown timers that feel manipulative. State the end date clearly.

### Localized Pricing
- **Launch at US price points only**, then enable App Store automatic pricing for other regions in the App Store Connect "Price and Availability" settings. Let Apple's pricing tier system translate automatically to Tier 5–6 equivalents.
- Do not manually manage regional pricing at launch. Re-evaluate after 60 days if significant non-US volume warrants manual adjustment (e.g., UK, CA, AU are typically close to US tiers and need little adjustment; India and Southeast Asia warrant significant reduction).

---

## Market Evidence

| App | Category | Relevant Features | Pricing Model & Current Price | What Pencild Should Learn | Source |
|---|---|---|---|---|---|
| **EventScan** | Direct: image → calendar | Unlimited scans (paid); 5 scans free/month; .ics export; Event History | Freemium. Pro: **$4.99/mo, $29.99/yr**. No trial. | Free scan limit benchmark (5/mo); Pencild's Plus at $3.99/mo undercuts on price while offering more | [App Store](https://apps.apple.com/us/app/eventscan-picture-to-calendar/id6737088852) |
| **Calendarco** | Direct: event scanner | AI calendar event extraction; basic event history | Freemium. **$1.99/mo, $19.99/yr**. No trial. | Lowest-price direct competitor sets the floor. Pencild is meaningfully better and should price above this. | [App Store](https://apps.apple.com/us/app/calendarco-event-scanner/id6504715509) |
| **Flits** | Direct: screenshots → calendar | Screenshot import; Quick Save; Smart Scan (iOS, Pro) | Freemium, unknown Pro price. "Free to start, no credit card." | Confirms freemium is the market norm for this category; establishes that $0 entry is expected | [getflits.app](https://getflits.app/) |
| **Genius Scan** | Adjacent: document scanner | OCR; cloud sync; PDF multi-page; batch mode | Freemium. Ultra: **$39.99/yr** (annual only; no monthly listed). | $39.99/yr is the reference for a capable document scan utility. Pencild Premium at $39.99/yr aligns precisely. | [thegrizzlylabs.com](https://thegrizzlylabs.com/genius-scan/pricing/) |
| **Adobe Scan** | Adjacent: OCR scanner | OCR; PDF creation; compression; merge/edit | Freemium. Pro: **$9.99/mo** (annual approx. $119.88/yr). | Adobe's monthly price is a high anchor. Pencild Premium at $6.99/mo is clearly more accessible. | [App Store / essexsoftware](https://essexsoftware.com/scaniva/best-scanner-app-iphone/) |
| **Fantastical** | Adjacent: calendar app | Scheduling; unlimited calendar sets; Openings; weather | Freemium. Individual: **$6.99/mo or ~$57/yr** ($4.75/mo). 14-day trial. | Confirms $6.99/mo is a credible price point for a focused iOS productivity subscription. Premium can match this. | [morgen.so](https://morgen.so/blog-posts/fantastical-pricing) |
| **PDF Expert** | Adjacent: PDF tool | PDF editing, annotation, conversion, signing | Subscription. ~**$49.99/yr** (annual). No free functional tier. | Power-user PDF pricing benchmark. Pencild Premium at $39.99/yr is slightly under, appropriate for a more focused use case. | [App Store](https://apps.apple.com/us/app/pdf-expert-editor-reader/id743974925) |
| **Scaniva** | Adjacent: scanner | OCR in 14 languages; unlimited scans; receipt/business card modes | **One-time $12.99** (no subscription). 10 free scans. | One-time purchase shows strong user preference for simplicity, but limits LTV and reinvestment. Not recommended for Pencild given ongoing OCR/AI cost. | [essexsoftware.com](https://essexsoftware.com/scaniva/best-scanner-app-iphone/) |

**Key competitive insight:** The direct image-to-calendar category (EventScan, Calendarco, Flits) is priced at $1.99–$4.99/month, with minimal differentiation and no free trial. Pencild's Plus tier at $3.99/mo with a 7-day trial and stronger reminders/calendar integration is immediately more credible. The Premium tier at $6.99/mo / $39.99/yr has no direct competitor — it occupies the gap between cheap image-scanning apps and expensive full document tools.

---

## Conversion Strategy

### Paywall Structure

> **Superseded 2026-10-13:** the app uses separate Plus and Premium interstitial paywalls, opened from the feature the user tried, not one shared comparison paywall. See the Decision Record at the top of this document for what shipped.

**One shared comparison paywall** showing all three plans side-by-side. Do not build two separate paywalls (one for Free→Plus, one for Plus→Premium). A single comparison paywall:
- Lets users self-select into Premium without a two-step upgrade journey
- Creates natural anchoring (Premium makes Plus look like a deal)
- Simplifies paywall A/B testing surface
- Is standard practice in mature iOS utility apps

Layout recommendation: plan cards in order Free | Plus | Premium, with Plus highlighted as "Most Popular." Annual billing as default toggle state. Monthly toggle available but not default.

### Paywall Triggers

> **Superseded 2026-10-13:** the free limit is 10 scans a month, so the hard gate is the 11th scan; every paid control also opens the paywall when tapped without the plan. See the Decision Record at the top of this document for what shipped.


| Trigger | Upgrade Path | Moment | Recommended Copy |
|---|---|---|---|
| 7th scan in a month | Free → Plus | Hard gate at limit | "You've used all 7 free scans this month. Upgrade to Plus for unlimited scans — try free for 7 days." |
| User taps "Import from Files" | Free/Plus → Premium | Soft gate with explanation | "PDF and document import is a Pencild Premium feature. Upgrade to scan schedules, itineraries, and multi-page agendas." |
| User taps "Scan another document" in batch flow | Free/Plus → Premium | Soft gate | "Batch scanning is included with Premium. Process up to 10 documents at once — try Premium free for 7 days." |
| User tries to set a 2nd reminder | Free → Plus | Contextual nudge | "Multi-stage reminders are a Plus feature. Get reminder schedules at 1 week, 3 days, and morning of the event." |
| User views scan history beyond 30 days | Free → Plus | Soft gate on older entries | "Scans older than 30 days are archived with Plus. Upgrade to access your full scan history." |
| After first successful scan + save | Free → Plus | Post-success upsell | "Event saved to your calendar. Want unlimited scans and multi-stage reminders? Start your 7-day free trial." |
| App launch Day 3 (if not subscribed) | Free → Plus | In-app prompt (one time only) | "You've saved [N] events with Pencild. Upgrade to Plus for unlimited scans and smarter reminders." |

### Soft vs. Hard Gates
- **Hard gate:** Scan limit reached. The user cannot scan another image until the month resets or they upgrade. This is the primary conversion mechanism.
- **Soft gate:** PDF import, batch scanning, multi-page PDF, advanced calendar rules. Show an upgrade sheet with feature explanation and CTA. User can dismiss. Never block the core image scan workflow with a soft gate.
- **Never gate:** Review/edit, single-reminder, basic calendar save. Gating these makes the app feel broken and increases refund requests.

### Default Plan on Paywall
**Annual Plus** is the default selected plan when the paywall opens. Rationale: most users are Plus-appropriate (not Premium), and annual selection maximizes LTV for those who convert. Annual-dominant apps generate approximately 2× Day-60 revenue per install ($0.46 vs. $0.24 per RevenueCat 2026).

### Upgrade Copy Principles
- Lead with what the user was trying to do, not with the tier name
- Keep CTAs to one sentence: "Try Plus free for 7 days" or "Upgrade to Premium"
- On the paywall, show: feature list → price → trial disclosure → CTA button
- Under the CTA: gray-text disclosure: "7-day free trial, then $X/month. Cancel anytime."
- Do not use countdown timers, artificial scarcity, or manipulative "last chance" language during free trials

### Ethical Behavioral Principles Applied
- **Value first:** Users see the scan → review → save loop on their first session, before any paywall appears
- **Contextual timing:** Upgrade prompts appear exactly when a user reaches a limit or tries a Premium feature — not on cold app launch
- **Single interrupt rule:** Show an upgrade prompt only once per trigger per 7-day window. Do not badger.
- **Trial transparency:** Show trial end date, price, and cancellation instructions on the subscription confirmation sheet
- **Clean cancellation:** Never use "pause" to disguise cancellation or reduce the number of confirmed cancels

---

## Proposed Features

| Feature | Best Tier | Why Users Would Pay | Implementation Complexity | Launch Scope |
|---|---|---|---|---|
| Smart event discovery from Photos | Premium | Surfaces events the user forgot to scan; high perceived AI value | High — requires Photo Library background access, indexing, App Review risk around privacy | **Post-launch** (v1.2+) |
| Event triage/ranking | Premium | Reduces noise for power users with many screenshots | Medium — depends on smart discovery above | **Post-launch** |
| Custom reminder templates | Plus | Saves repeat setup for common event types (game days, concerts, school pickup) | Low | Post-launch (v1.1) |
| Export/share formats (.ics) | Plus | Makes Pencild interoperable with other calendar tools; competitive with EventScan | Low | Post-launch (v1.1) |
| Recurring scan routines | Premium | Automates periodic imports (weekly PDF schedules) | High — requires App Intents + Background Tasks | **Post-launch** |
| Widgets | Plus | High-visibility feature that drives organic discovery and retention | Medium — WidgetKit; straightforward but needs design work | Post-launch (v1.1) |
| Shortcuts / App Intents | Plus | Power user delight; shows up in App Store "Works with Shortcuts" | Medium — App Intents framework; manageable | Post-launch |
| Calendar color/category rules | Premium | Auto-route "soccer" events to the right calendar; appeals to parents and admins | Low-Medium — Calendar EventKit write | Bundle with Premium advanced rules launch |
| Location/geofence reminders | Premium | Context-aware "remind me when I leave" before events | High — requires Always-On Location permission; significant App Review and user trust risk. Must clearly disclose. | **Avoid at launch; evaluate in v2** |
| Event conflict detection | Plus or Premium | Warns users if a new event overlaps an existing one | Medium — requires Calendar read access (separate user permission prompt) | Post-launch |
| Family/household sharing | TBD | Premium for household; aligns with Apple Family Sharing | High — Family Group entitlement, subscriber management, support complexity | **Post-launch; evaluate after launch** |
| AI event-planning suggestions | Premium | "This looks like a recurring event — want to block the whole series?" | High — requires cloud inference; adds per-user AI inference cost; do not include at launch | **Post-launch** |
| Cross-device sync/backup | Premium | Users expect continuity; reduces churn in power users | High — requires iCloud CloudKit or proprietary backend | **Post-launch (v1.2+)** |
| Google Drive / Dropbox import | Premium | Lets power users import from shared document sources | High — OAuth, third-party APIs, App Review | **Post-launch** |

---

## Risks and Validation Plan

### Revenue and Conversion Assumptions That Need Testing
- **Freemium conversion:** Assumed at 3–5% (above market median of 2.1%, achievable given the strong first-session magic). Validate at Day 30.
- **Trial-to-paid:** Assumed at 35–40% (within market range for 7-day trials). If below 25%, investigate Day-0 value delivery.
- **Annual plan uptake:** Targeted at 50%+ of paying subscribers. Baseline market is ~34%; with annual as default selection and 48–52% discount framing, 50% is achievable.
- **Premium upgrade rate from Plus:** Assumed at 10–15% of Plus subscribers over 90 days. Validate by tracking PDF import tap rate in Plus users.
- **OCR/AI cost per scan:** Validate that 7 free scans/month + Plus unlimited does not create a cost-per-user problem at scale. On-device intelligence reduces per-scan cost significantly.

### Pricing Experiments to Run After Launch
1. **Free scan limit:** A/B test 5 scans/mo vs. 7 scans/mo vs. 10 scans/mo. Track conversion rate and time-to-paywall. (Hypothesis: 7 outperforms 5 on trust, nearly matches 5 on conversion rate.)
2. **Default plan selection:** A/B test Annual Plus as default vs. Monthly Plus as default. Measure Day-30 and Day-60 revenue per install.
3. **Trial length:** Test 7-day vs. 3-day trial. Hypothesis: 7-day converts better for this utility due to infrequent-but-recurring use patterns.
4. **Paywall timing:** A/B test showing paywall after first successful scan vs. only when limit is hit. Measure install-to-trial starts.
5. **Launch promotion depth:** A/B test 20% vs. 30% first-year discount. Measure trial conversion and annual renewal rate.
6. **Lifetime offer:** After 90 days of data, decide whether to re-introduce lifetime as a permanent option or retire it.

### Metrics to Track
- **Install → first scan rate** (target: >70%)
- **First scan → calendar save rate** (target: >60%)
- **Scan limit hit rate** (how many Free users hit the 7/mo cap)
- **Paywall impression → trial start** (target: 8–12%)
- **Trial start → paid conversion** (target: 35–40%)
- **Monthly → annual upgrade rate within 90 days**
- **30-day and 90-day subscriber retention**
- **PDF import tap rate in Free/Plus users** (Premium upgrade signal)
- **Day-0 trial cancel rate** (target: <45%)
- **Refund rate** (flag if >2%)
- **Revenue per install at Day 30/60/90**

### App Store Review, Privacy, and User-Trust Considerations
- **Calendar write access:** Prompted on first calendar save. Frame clearly: "Pencild needs access to add events to your calendar." No access = no core value. Minimize scope.
- **Photo Library access:** Prompt for "Limited" photo access at first scan (iOS 14+). Allow users to grant access to selected photos only. Full library access is not required for core functionality.
- **Files/PDF access:** Files app integration uses standard document picker (UIDocumentPickerViewController). No special entitlement needed; no user permission dialog beyond the standard picker. Low risk.
- **Location (if added later):** Always-On Location or Significant Location Change requires explicit user justification in App Store review and a clear privacy disclosure. Do not add to launch scope.
- **Background processing:** Smart discovery (proposed) would require background app refresh permission. Requires careful App Review justification.
- **On-device vs. cloud inference:** Wherever possible, use on-device OCR (Vision framework) to avoid per-request cloud costs and to support the "private by design" App Store messaging. Flag clearly if cloud inference is ever used.
- **Subscription disclosure:** StoreKit handles billing transparency. Ensure the paywall shows trial end date, renewal price, and cancellation path before the user taps the CTA. This is required by App Store guidelines and reduces refund risk.

### 30/60/90-Day Pricing Validation Plan

**Day 0–30 (Launch validation)**
- Monitor install → trial → paid funnel daily
- Track which paywall triggers generate the most trial starts
- Watch for high Day-0 trial cancellations (>50% = paywall is showing too early or value delivery is weak)
- Check refund rate weekly

**Day 31–60 (Optimization)**
- Launch A/B test #1: free scan limit (5 vs. 7 vs. 10)
- Launch A/B test #2: default plan selection (Annual vs. Monthly)
- Review PDF import tap rates to validate Premium upgrade funnel
- Evaluate lifetime promotion performance; decide whether to extend or retire

**Day 61–90 (Iteration)**
- Review 30-day subscriber retention; if below 70%, investigate onboarding and reminder value
- Decide on trial length test (7-day vs. 3-day)
- Price review: if conversion is above 10% install-to-paid, consider whether Plus pricing has room to increase to $4.99/mo (re-evaluate at Day 90 with data)
- Prepare for App Store feature request submission (a strong scan-and-save utility is a good candidate for "Apps We Love" editorial)

---

## Final Launch Configuration

> **Superseded 2026-10-13:** the configuration below was the original proposal. Shipped: free plan of 10 scans a month (only scans that find a new event), 1 alert per event, no history limit, and no per-session save cap; lifetime $39.99/$79.99 through 2027-04-13; 1-week trials on monthly and annual plans; Premium adds work schedules and multi-date flyers. See the Decision Record at the top of this document for what shipped.


### Free Tier
- 7 image/screenshot scans per month
- Single reminder per event
- Apple Calendar save (up to 3 events per session)
- 30-day scan history
- Review and edit before saving (always on)
- On-device OCR and intelligence

### Pencild Plus
- **Monthly:** $3.99
- **Annual:** $24.99/yr (~$2.08/mo, 48% savings)
- **Lifetime (launch promo, 90 days only):** $59.99
- **Trial:** 7 days free
- Unlimited image/screenshot scans
- Multi-stage reminders (up to 3 per event)
- Unlimited Apple Calendar saves
- 90-day scan history
- Standard email support

### Pencild Premium
- **Monthly:** $6.99
- **Annual:** $39.99/yr (~$3.33/mo, 52% savings)
- **Lifetime (launch promo, 90 days only):** $99.99
- **Trial:** 7 days free
- Everything in Plus
- Files/PDF document import
- Multi-page PDF scanning (agendas, schedules, itineraries)
- Batch scanning (up to 10 documents)
- Advanced calendar rules (auto-route by keyword/calendar)
- Unlimited scan history and archive
- Priority support
- Early access to new features

### Trial
- 7-day free trial on both Plus and Premium
- Annual plan pre-selected on paywall
- Day 5 in-app push: "Your free trial ends in 2 days"
- Clear billing disclosure below CTA: "7-day free trial, then [price]. Cancel anytime in Settings."

### Default Paywall Plan
- **Annual Plus** pre-selected
- "Most Popular" badge on Plus
- "Best for Documents" badge on Premium
- Monthly toggle available but not default

### Launch Promotion
- 30% off first year (Annual plans only): Plus $17.49, Premium $27.99
- Labeled "Launch Special" with specific end date (90 days post-launch)
- No countdown timer. No manipulative language. End date stated clearly.
- Lifetime options visible on paywall below the subscription plans for early adopters

### Features to Defer to Post-Launch
- Smart event discovery from Photos (v1.2+)
- Location/geofence reminders (evaluate in v2.0)
- Custom reminder templates (v1.1)
- Export/share formats (.ics) (v1.1)
- Widgets (v1.1)
- Shortcuts / App Intents (v1.1)
- Cross-device sync (v1.2+)
- Google Drive / Dropbox import (v1.2+)
- Event conflict detection (v1.1)
- AI event-planning suggestions (v2.0+)
- Family sharing (evaluate post-launch)

---

*Sources: [EventScan App Store](https://apps.apple.com/us/app/eventscan-picture-to-calendar/id6737088852) · [Calendarco App Store](https://apps.apple.com/us/app/calendarco-event-scanner/id6504715509) · [Genius Scan Pricing](https://thegrizzlylabs.com/genius-scan/pricing/) · [Fantastical Pricing via morgen.so](https://morgen.so/blog-posts/fantastical-pricing) · [PDF Expert App Store](https://apps.apple.com/us/app/pdf-expert-editor-reader/id743974925) · [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps) · [Adapty Trial Conversion Benchmarks](https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/) · [RevenueCat Lifetime Subscriptions](https://www-docs.revenuecat.com/blog/growth/lifetime-subscriptions) · [Scaniva/Competitor Comparison](https://essexsoftware.com/scaniva/best-scanner-app-iphone/) · [getflits.app](https://getflits.app/)*
