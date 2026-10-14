# Pencil’d Monetization and Positioning Review

The current product, pricing, and tier structure are coherent and should **not** be reworked before launch. The highest-value changes are improved App Store creative, contextual paywall messaging, privacy-compatible StoreKit reporting, a rating prompt, and a distinct work-schedules acquisition page.

## Current baseline

| Plan | Current offer | Actual value proposition |
|---|---|---|
| **Free** | 10 qualifying scans monthly; one alert per event; unlimited history | Complete photo-to-calendar workflow with review before saving |
| **Plus** | $3.99 monthly, $24.99 annual, $39.99 lifetime | Unlimited scans, three alerts, automatic screenshot detection, likely-event triage |
| **Premium** | $6.99 monthly, $39.99 annual, $79.99 lifetime | Everything in Plus, plus PDF/file import, schedules and multi-date flyers, duplicate grouping, and tailored reminders |

Only scans that find a new event consume the free allowance. Lifetime products remain available through April 13, 2027, and both recurring periods currently carry a one-week introductory trial.

These are local StoreKit and product decisions; they do **not** establish that live App Store Connect products, prices, trials, subscription levels, or availability are configured identically.

## Decision verdict

| Area | Decision | Confidence |
|---|---|---|
| Free allowance | Keep 10 qualifying scans | High |
| Tier structure | Keep Free, Plus, Premium | High |
| Current prices | Keep for launch | High |
| Lifetime offers | Keep through the existing deadline | Medium-high |
| One-week trial | Keep initially | Medium-high |
| Annual default | Keep | High |
| Separate contextual paywalls | Keep | High |
| App name | Keep | High |
| Subtitle | Keep for the initial release | Medium-high |
| Keyword field | Revise | Medium |
| Screenshots | Redesign before launch | High |
| Custom product pages | Add work-schedules page first | High |
| Rating prompt | Add | High |
| Special last-scan warning | Add | High |
| Promoted subscriptions | Defer until purchase-intent handling exists | High |
| In-app analytics | Do not add | High |

## Store positioning

### Keep the name

**Pencil’d: Photo to Calendar** communicates the category immediately and places the clearest search phrase in the highest-value metadata field. Apple confirms that title, subtitle, keywords, and primary category all contribute to text relevance in search.

The brand apostrophe must remain consistent in every customer-facing asset. Internal source identifiers can remain `Pencild`.

### Keep the subtitle

The current subtitle—**“Flyers & screenshots to events”**—covers three important concepts that the name does not: flyers, screenshots, and events.

Do not replace it with “Scan Flyers & Schedules” yet. That alternative adds schedules but sacrifices screenshot and event coverage, and Product Page Optimization cannot test subtitles—it tests icons, screenshots, and previews only.

Use a work-schedules Custom Product Page to test schedule-oriented demand before surrendering existing metadata coverage.

### Revise keywords

Recommended candidate:

```text
picture,image,scan,work,schedule,shift,roster,timetable,agenda,appointment,pdf,import,reminder,date
```

This is 99 characters, avoids terms already present in the name and subtitle, and replaces lower-intent terms such as `party`, `camera`, and generic `file` with task-oriented schedule terminology. Apple recommends avoiding repeated words and limits the keyword field to 100 characters.

This remains an ASO hypothesis—not a claim that these terms have verified search volume. Validate them later through Custom Product Page reach, Apple Ads search-term data if ads are introduced, and overall search-source conversion.

### Sharpen the promise

Recommended description opening:

> Stop retyping dates. Pencil’d turns photos, flyers, screenshots, PDFs, and work schedules into calendar events you review before anything reaches Apple Calendar.

Recommended promotional text:

> Turn photos, flyers, work schedules, PDFs, and screenshots into reviewed calendar events and reminders—privately on your iPhone.

This preserves the discoverable category language while foregrounding Pencil’d’s strongest trust differentiator: **review before save**.

## Screenshot strategy

The first three screenshots should establish the problem, prove difficult extraction, and resolve accuracy concerns.

| Order | Caption | Visual proof |
|---|---|---|
| 1 | **Stop retyping dates.** | Flyer or screenshot beside the extracted event |
| 2 | **Turn a full schedule into separate events.** | Dense work schedule followed by multiple extracted shifts |
| 3 | **Review every detail before it saves.** | Editable title, date, time, location, and destination calendar |
| 4 | **Import PDFs and files—every page.** | Multi-page PDF moving into Batch Review |
| 5 | **Find event screenshots automatically.** | Plus screenshot detection and likely-event highlighting |
| 6 | **Processed on your device. Not collected.** | Privacy-focused product screen, not an abstract marketing graphic |

Badge Premium-only screenshots clearly. This prevents the schedule and PDF proof from implying that every advertised capability is included free.

### First optimization test

After the app reaches Ready for Distribution, run a Product Page Optimization test changing **only the first screenshot**:

- Control: event flyer
- Treatment A: work schedule
- Treatment B: school or family schedule

Apple randomizes eligible visitors and reports estimated conversion lift and confidence; tests can include up to three treatments. Do not simultaneously change the icon, remaining screenshots, or preview video.

## Custom product pages

Create these in order:

1. **Work Schedules:** “Turn every shift into its own calendar event.”
2. **School and Family:** “Turn school calendars and activity schedules into plans.”
3. **Flyers and Events:** “Scan the flyer. Review the details. Save the event.”

Each page should have audience-specific screenshots, promotional text, and keywords. Apple permits up to 70 pages, can surface keyword-enabled pages in relevant searches, and reports impressions, downloads, conversion, retention, and downstream proceeds by page.

The work-schedules page is the priority because it gives Premium a concrete, high-frequency job rather than positioning it merely as “Plus with more features.”

## Pricing review

Pencil’d Plus is competitively positioned:

- Lumical: $19.99 annual and $29.99 lifetime.
- Calendarco: $1.99 monthly and $19.99 annual.
- EventScan: $4.99 monthly and $29.99 annual.
- Image to Calendar Scanner: $4.99 monthly and $29.99 annual.

At $3.99 monthly and $24.99 annually, Plus sits near the middle of the direct category. Premium’s $6.99 monthly and $39.99 annual pricing is defensible only when its schedule splitting, multi-page imports, duplicate grouping, and reminder planning are clearly demonstrated.

### Keep lifetime

The previous cloud-cost argument for removing lifetime does not apply. Pencil’d’s extraction is local-first, and the existing lifetime availability is genuinely limited by an enforced date.

The trade-off is cannibalization:

- Plus lifetime is approximately 1.6 times its annual price.
- Premium lifetime is approximately 2 times its annual price.

Keep both through the announced period, but report lifetime units and proceeds separately from recurring plans. Do not extend, remove, or raise them until enough real transactions exist to determine whether they expand paid conversion or primarily replace annual subscriptions.

### Keep the trial

RevenueCat reports 37.4% median trial-to-paid conversion for 5–9-day trials versus 35.4% for 10–16-day trials; its data therefore does not establish that moving from seven to fourteen days would improve conversion. Fourteen-day trials do have a lower share of cancellations occurring on day zero—35.7% versus 39.8% for seven-day trials—but that statistic describes the timing of cancellations, not the proportion of all trial starters who cancel.

Keep seven days for launch. Reconsider trial length only after Pencil’d has enough trial starts and conversions to compare sequential offer cohorts in App Store Connect.

Apple permits only one introductory offer redemption per subscription group. Therefore, messaging should say **“One-week trial for eligible new members”**, not imply that users receive separate Plus and Premium trials.

## Paywall review

The separate paywalls are appropriate because they open when the user attempts a specific paid feature. Both already select annual by default, show localized StoreKit pricing, expose lifetime only during the offer window, and include restore, privacy, and terms links.

The main weakness is that their opening copy is static even when the conversion context differs.

### Contextual opening copy

| Trigger | Recommended paywall lead |
|---|---|
| One scan remaining | **Keep scanning without monthly limits.** |
| Scan allowance exhausted | **Your next scan is ready when you are.** |
| Automatic detection | **Let Pencil’d surface new event screenshots.** |
| Likely-event triage | **See which screenshots look like events first.** |
| Additional alert | **Add up to three alerts to every event.** |
| PDF import | **Import every page from PDFs and Files.** |
| Work schedule | **Turn every shift into its own event.** |
| Duplicate filter | **Find likely duplicates across your archive.** |
| Tailored reminder | **Get reminder timing designed for the event.** |

The feature attempted should become the first highlighted benefit. Preserve the rest of the plan list below it.

### Trial disclosure

Consolidate trial terms near the CTA:

> **1 week free, then $24.99/year. Renews annually until cancelled.**

Apple recommends showing the trial duration and the standard amount charged afterward clearly within the purchase flow. Current information is present across the option, button, and renewal text, but a single explicit sentence would be easier to understand.

### Resume intent

After a successful upgrade, return users directly to the feature they attempted—or resume it automatically where safe. This is already implemented for some Home batch flows; applying the same principle to PDF import and other contextual gates would reduce post-purchase friction.

Do not reintroduce a large cross-tier feature matrix. The current contextual Plus and Premium paywalls better match the product’s paywall-on-attempt architecture.

## Conversion improvements

### Rating prompt

No StoreKit rating request currently appears in the source. Add one after the third or fourth successful save, once the completion screen has settled—not during onboarding, immediately following purchase, after an error, or synchronously in response to the Save tap.

Apple recommends requesting a review after a successfully completed sequence and limits system presentation to a maximum of three times within 365 days. Track locally whether the current app version has already requested it; no analytics event is necessary.

### Final-scan warning

Home already displays the remaining allowance, including “1 of 10 free scans left,” but one remaining scan receives no special treatment.

Add an amber state at one remaining:

> **1 free scan left this month**  
> Only scans that find a new event count. Upgrade for unlimited scanning.

This creates a fair pre-limit upgrade opportunity without manufacturing urgency.

### Promoted subscriptions

Defer this feature. Current source contains no `PurchaseIntent` or legacy promoted-purchase handler.

Apple requires the app to receive and complete purchases initiated from the App Store before promoted products are enabled. Implement and test that lifecycle before promoting any subscription or lifetime SKU.

## Privacy-safe measurement

Do not add paywall impressions, scan-source events, extraction telemetry, field-edit tracking, or conversion SDKs. Repository policy explicitly prohibits remote services or analytics without a separately approved task.

Use this measurement framework instead:

| Question | Metric | Source |
|---|---|---|
| Is visibility increasing? | Impressions and product-page views by source and territory | App Store Analytics |
| Does the listing convert? | First-time downloads and product-page conversion rate | App Store Analytics |
| Which audience message works? | CPP impressions, downloads, conversion, retention, proceeds | Custom Product Page analytics |
| Which creative works? | PPO estimated lift and confidence | Product Page Optimization |
| Are trials converting? | Plan starts and introductory-offer conversion | Subscription analytics |
| Which tier wins? | Units and proceeds by Plus/Premium SKU | Sales and Trends reports |
| Are users upgrading? | Upgrade, downgrade, crossgrade, and renewal events | Subscription Event reports |
| Does lifetime cannibalize? | Lifetime units/proceeds versus annual starts/proceeds | Summary Sales and Subscription reports |
| Is recurring value durable? | Renewal, retention, voluntary churn, refunds | Subscription analytics |
| Is trust improving? | Rating count, average rating, and review themes | App Store Connect |

Apple provides subscription starts, paid conversion, renewals, churn, MRR, retention, and product-level reports without requiring an analytics SDK.

This framework cannot reveal which in-app feature caused a purchase. Consequently, Product Page Optimization and Custom Product Pages can support causal store-level decisions, while paywall-copy and product-flow changes should be treated as directional unless a separately approved privacy-preserving measurement task is undertaken.

## Execution order

### Before submission

- Verify all six live product IDs, prices, territories, and availability against the local StoreKit catalog.
- Confirm Premium sits above Plus in the App Store subscription group.
- Confirm eligible users receive one seven-day trial across the membership group.
- Create both lifetime non-consumables and document the manual April 14, 2027 removal step.
- Produce the six-screen default screenshot set.
- Replace the keyword field with the schedule-oriented candidate.
- Verify support, privacy, and marketing URLs.
- Verify every customer-facing instance uses **Pencil’d**.

### First update

- Add the successful-save rating prompt.
- Add the special one-scan-remaining state.
- Consolidate trial-to-renewal disclosure.
- Pass the attempted feature into each paywall so the hero message is contextual.
- Resume the blocked action after successful purchase where safe.

### After distribution

- Launch the first-screenshot Product Page Optimization test.
- Publish the work-schedules Custom Product Page.
- Establish a baseline for plan starts, trial conversion, annual versus monthly mix, lifetime units, and renewal.
- Add school/family and event-flyer pages only after the work-schedules page has enough traffic to interpret.
- Revisit trial duration and lifetime pricing only after transaction volume supports a real decision.

**Bottom line:** keep the existing product model and prices. Position Pencil’d around **photo-to-calendar convenience, difficult schedule extraction, user review, and on-device privacy**, then improve conversion through screenshots, contextual merchandising, ratings, and Apple’s privacy-compatible store analytics.

## Sources

Inline citation numbers were removed because they no longer matched this list. Repository facts come from the Decision Record in `docs/business/Pencild-Monetization-Strategy.md`, `Pencild.storekit`, `AGENTS.md`, and the source files named in the text. External sources consulted:

- [App Store search](https://developer.apple.com/app-store/search/)
- [Overview of product page optimization](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/overview-of-product-page-optimization)
- [Configure multiple product page versions - Create custom...](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions/)
- [Custom Product Pages - App Store](https://developer.apple.com/app-store/custom-product-pages/)
- [Lumical - Scan to Calendar - App Store - Apple](https://apps.apple.com/us/app/lumical-scan-to-calendar/id6753274309)
- [Calendarco: Event Scanner App - App Store](https://apps.apple.com/us/app/calendarco-event-scanner/id6504715509)
- [EventScan: Picture to Calendar - App Store - Apple](https://apps.apple.com/us/app/eventscan-picture-to-calendar/id6737088852)
- [Image to Calendar Scanner - App Store - Apple](https://apps.apple.com/us/app/image-to-calendar-scanner/id6755790394)
- [State of Subscription Apps 2026 – RevenueCat](https://www.revenuecat.com/state-of-subscription-apps?from=google)
- [www.empact.partners · empact-zone · free-trial-conversion111 Free Trial Conversion Statistics - empact.partners](https://www.empact.partners/empact-zone/free-trial-conversion-statistics)
- [Auto-renewable Subscriptions - App Store](https://developer.apple.com/app-store/subscriptions/)
- [Set up introductory offers for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/)
- [developer.apple.com › design › human-interfaceApple In-App Purchase | Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase)
- [Requesting App Store reviews](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews)
- [Supporting promoted Apple In-App Purchases in your app](https://developer.apple.com/documentation/storekit/supporting-promoted-in-app-purchases-in-your-app)
- [Download and view reports - App Store Connect - Help](https://developer.apple.com/help/app-store-connect/measure-app-performance/download-and-view-reports/)
- [App Store Connect Analytics - Help - Apple Developer](https://developer.apple.com/help/app-store-connect-analytics/)
- [developer.apple.com › help › app-store-connectSubscriptions - Monetization - App Store Connect Analytics...](https://developer.apple.com/help/app-store-connect-analytics/monetization/subscriptions)
- [View subscription data - Measure app performance - Apple Developer](https://developer.apple.com/help/app-store-connect/measure-app-performance/view-subscription-data/)
- [Screenshots to Calendar - App Store - Apple](https://apps.apple.com/us/app/screenshots-to-calendar/id6757425886)
- [Screenshot to Calendar](https://apps.apple.com/us/app/screenshot-to-calendar/id6741306030)
- [Screenshot+Pdf to Calendar App - App Store](https://apps.apple.com/us/app/screenshot-pdf-to-calendar/id6741306030)
- [Screenshot Calendar - App Store - Apple](https://apps.apple.com/us/app/screenshot-calendar/id6761320983)
- [Photo to Calendar - App Store - Apple](https://apps.apple.com/us/app/photo-to-calendar/id6760813080)
- [ScheduleScanner - App Store - Apple](https://apps.apple.com/us/app/schedulescanner/id6745990089)
- [Notis: Screenshot to Calendar - App Store - Apple](https://apps.apple.com/us/app/notis-screenshot-to-calendar/id6766415043)
- [EventShot - Image To Calendar - App Store - Apple](https://apps.apple.com/us/app/eventshot-image-to-calendar/id6747011235)
- [Photo To Calendar | PCalendar - App Store - Apple](https://apps.apple.com/us/app/photo-to-calendar-pcalendar/id6751649479)
- [CalKok: Screenshot to Calendar - App Store - Apple](https://apps.apple.com/us/app/calkok-screenshot-to-calendar/id6775320319)
- [Photo to Calendar](https://apps.apple.com/us/app/photo-to-calendar/id6746355733)
- [Added App - App Store - Apple](https://apps.apple.com/us/app/added-app/id6759643335)
- [EventShot - Image To Event on the App Store](https://apps.apple.com/us/app/eventshot-image-to-event/id6747011235)
- [Photo to Calendar: Snap Event - App Store - Apple](https://apps.apple.com/us/app/photo-to-calendar-snap-event/id6751177493)
- [MARGIN - Never Forget - App Store - Apple](https://apps.apple.com/us/app/margin-never-forget/id6758026096)
- [Calendarco: Scan & Add Events](https://apps.apple.com/us/app/calendarco-scan-add-events/id6504715509)
- [‎Lumical - 캘린더 스캐너 앱 - App Store](https://apps.apple.com/us/app/lumical-%EC%BA%98%EB%A6%B0%EB%8D%94-%EC%8A%A4%EC%BA%90%EB%84%88/id6753274309?l=ko)
- [Приложение «Lumical: фото в календарь - App Store - Apple](https://apps.apple.com/us/app/lumical-%D1%84%D0%BE%D1%82%D0%BE-%D0%B2-%D0%BA%D0%B0%D0%BB%D0%B5%D0%BD%D0%B4%D0%B0%D1%80%D1%8C/id6753274309?l=ru)
- [AI Calendar Scanner: Photo ICS - App Store - Apple](https://apps.apple.com/us/app/ai-calendar-scanner-photo-ics/id6504715509)
- [Calendarco](https://apps.apple.com/us/app/calendarco/id6504715509?l=fr-FR)
- [تطبيق PicCal: Calendar Event Scanner - App Store - Apple](https://apps.apple.com/us/app/piccal-calendar-event-scanner/id6745625648?l=ar&platform=watch)
- [Lumical - Scan vers Calendrier - App Store - Apple](https://apps.apple.com/us/app/lumical-scan-vers-calendrier/id6753274309)
- [‎iFNB - You Might Also Like - App Store - Apple](https://apps.apple.com/us/app/328979438?see-all=customers-also-bought-apps&platform=iphone)
- [‎App PicCal: Calendar Event Scanner – App Store](https://apps.apple.com/us/app/piccal-calendar-event-scanner/id6745625648?l=pt-BR&platform=ipad)
- [ShiftScan: Shift Work Calendar - App Store - Apple](https://apps.apple.com/us/app/shiftscan-shift-work-calendar/id6797318870)
- [Creating Your Product Page - App Store](https://developer.apple.com/app-store/product-page/)
- [Sales and Trends metrics and dimensions - Reporting](https://developer.apple.com/help/app-store-connect/reference/reporting/sales-and-trends-metrics-and-dimensions/)
- [Sales and Trends reports availability - Reference - App Store Connect](https://developer.apple.com/help/app-store-connect/reference/reporting/sales-and-trends-reports-availability/)
- [Custom Product Pages | Apple Developer Documentation](https://developer.apple.com/documentation/apple_ads/custom-product-pages)
- [developers.apple.com › app-custom-product-pagesApp Custom Product Pages | Apple Developer Documentation](https://developer.apple.com/documentation/appstoreconnectapi/app-custom-product-pages)
- [Articles](https://developer.apple.com/app-store/articles/)
- [Summary Sales Report - App Store Connect](https://developer.apple.com/help/app-store-connect/reference/reporting/summary-sales-report/)
- [Submit Your APP](https://developer.apple.com/app-store/submitting/)
- [Promoting Apple In-App Purchases](https://developer.apple.com/documentation/storekit/promoting-in-app-purchases)
- [intents | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/purchaseintent/intents)
- [In-App Purchase](https://developer.apple.com/in-app-purchase/)
- [Simulate A Purchase](https://developer.apple.com/documentation/xcode/testing-in-app-purchases-with-storekit-transaction-manager-in-code)
- [Apple In-App Purchase | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/in-app-purchase)
- [Testing promoted Apple In-App Purchases](https://developer.apple.com/documentation/storekit/testing-promoted-in-app-purchases)
- [Browse The Latest Documentation](https://developer.apple.com/documentation/storekit/)
- [Promoting your Apple In-App Purchases - App Store](https://developer.apple.com/app-store/promoting-in-app-purchases/)
- [正在请求App Store评论| Apple Developer Documentation](https://developer.apple.com/cn/documentation/storekit/requesting-app-store-reviews)
- [requestReview(in:) | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/appstore/requestreview(in:)-1q8qs)
- [requestReview(in:) | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/appstore/requestreview(in:)-4r0y9)
- [Choosing a StoreKit API for Apple In-App Purchases](https://developer.apple.com/documentation/storekit/choosing-a-storekit-api-for-in-app-purchases)
- [How to Reduce Subscriber Churn: Proven Strategies | SubJolt](https://www.subjolt.com/guides/reduce-subscriber-churn/)
- [95% of Those Who Cancel Their Annual Subscriptions to...](https://www.sadanews.ps/en/news/305735.html)
- [I went through RevenueCat's subscription report and checked how many of our conversions happen in the first session. it was almost all of them.](https://www.reddit.com/r/TestMyApp/comments/1s5pe6d/i_went_through_revenuecats_subscription_report/)
- [Annual Churn Is A One-Month Problem - MarketMaze](https://www.marketmaze.me/p/annual-churn-is-a-one-month-problem)
- [The State of Subscription Apps in 10 minutes: lessons, trends, and...](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)
- [Subscription Billing Period: Weekly vs Monthly vs Annual - tasu](https://tasu.ai/library/subscription-billing-period-weekly-monthly-annual)
- [termsandconditionstemplate.com · app-revenueApp Revenue 2026: Median $72/Month, Top 10% Earn $2,500+ [Data]](https://termsandconditionstemplate.com/app-revenue-statistics-2026)
- [app-paywall-pilot/outputs/2026-paywall-research.md at main...](https://github.com/Nikolai-Iakubovskii/app-paywall-pilot/blob/main/outputs/2026-paywall-research.md)
- [RevenueCat's Subscription Infrastructure Falls Short](https://www.linkedin.com/posts/zenithkarri_i-spent-time-going-deep-on-revenuecat-the-activity-7488162138562375680-CgbN)
- [Do you pay for apps for a year in advance? You probably...](https://www.letemsvetemapplem.eu/en/2026/05/29/predplacite-si-aplikace-na-rok-dopredu-znovu-uz-to-pravdepodobne-neudelate/)
- [The 2026 State of Subscription Apps Report - Podcast Summaries](https://pod.wave.co/podcast/sub-club-by-revenuecat/the-2026-state-of-subscription-apps-report)
- [The post-purchase screen: how to stop Day 0 cancellations](https://www.revenuecat.com/blog/growth/post-purchase-screen)
- [The Top 10 Learnings From RevenueCat's State of Subscription Apps](https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps-how-115000-mobile-apps-deliver-16b-in-revenue-whats-working-whats-quietly-killing-growth/)
- [Set up offer codes - Manage subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/)
- [App Store Connect](https://developer.apple.com/app-store-connect/)
- [App Store Connect workflow - Get started - Apple Developer](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/)
- [developers.apple.com › documentation › appstoreTesting In-App Purchase and Subscriptions | Apple Developer...](https://developer.apple.com/documentation/appstoreconnectapi/testing-in-app-purchase-and-subscriptions)
- [Optimize subscriptions for success: acquisition - Tech Talks - Videos](https://developer.apple.com/videos/play/tech-talks/110151/)
- [Overview of testing in sandbox - Test In-App Purchases - App Store...](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)
- [What's new in Apple In-App Purchase - WWDC26 - Videos](https://developer.apple.com/videos/play/wwdc2026/210/)
- [Release Notes - App Store Connect - Apple Developer](https://developer.apple.com/help/app-store-connect/release-notes/)
- [App Store | Apple Developer Documentation](https://developer.apple.com/documentation/appstoreconnectapi/app-store)
- [Implementing introductory offers in your app](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app)
