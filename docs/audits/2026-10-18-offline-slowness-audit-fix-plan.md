# Pencil’d Offline Slowness: Diagnosis & Fix Plan

Oct 18, 2026 · @Aaron Roberson

## Summary

Pencil’d has no HTTP code; offline slowness comes from StoreKit entitlement checks that deny paid features until they resolve, plus a Photos image fetch with no cancellation, resize mode or iCloud fallback. This is from reading the code only (not built or run), so causes are ranked by likelihood.

Profile: Analytical. Repo reviewed: this repository (app target `Pencild`).

## Insights

1. **Entitlements fail closed while StoreKit is unresolved** (Supported by code, Actionable). `SubscriptionService` starts at `entitlementSnapshot = .checking()` and loops `Transaction.currentEntitlements` on the main-actor class. `.checking`, `.unverified` and `.unavailable` all deny every paid feature. Offline, StoreKit can stall or return unverified results, so Plus/Premium features show "still checking your subscription." The resolver also drops the whole tier to free if any one transaction fails verification, and nothing persists the last verified tier. This fits "most functionality not functioning." Speculative: I have not confirmed that `currentEntitlements` stalls on your device.
2. **Launch calls `Product.products(for:)` unconditionally** (Supported, Actionable). The `init` task runs `fetchProducts()` and sets `isLoading = true`. Offline it can run long before throwing, and paywall screens show "Loading price…" meanwhile. Prices are only needed on paywall screens.
3. **`fetchImage` has no cancellation, resize mode or iCloud handling** (Supported, Actionable). Network access is correctly off, but `PhotoLibraryService.fetchImage` never calls `cancelImageRequest`, so fast scrolling queues stale requests. With no `resizeMode`, a 360×640 thumbnail request can decode the full screenshot. If the original is iCloud-only ("Optimize iPhone Storage"), the result is `nil`, `AssetThumbnail` swallows the error with `try?`, and the spinner shows forever. Speculative: "doesn't resolve at all" could also be a continuation that never resumes.
4. **The PhotosPicker path silently depends on iCloud** (Supported). `loadTransferable(type: Data.self)` in `HomeEmptyStateView` and `BatchScanViewModel` downloads iCloud-only photos. Offline it fails or hangs, and `try?` hides it. This contradicts the "100% on-device" comment.
5. **Smaller offline touches** (Supported, low impact). `AppleAccount.validate()` calls `credentialState` from the profile view. The whole UI is `.disabled` while `scanViewModel.isProcessing`, so one hung scan makes the app look dead.

## Caveats and contradictions

- The Privacy Center promises "zero-cloud." A silent iCloud fetch, or a silent failure of one, means that claim is not fully true.
- There is no CloudKit, Firebase or analytics, so a network SDK is not the cause. If the app is also janky with Wi-Fi on, suspect image decoding rather than connectivity.
- I could not build Swift in this environment, so no change has been compiled or tested.

## Actionable next steps

**Status check 2026-10-20:** most fixes were implemented in uncommitted changes on 2026-10-19. Remaining work is marked below.

Fixes 1–3 are the smallest and remove the offline paid-feature lockout and the launch stall; do those first.

| # | Fix | Label | Effort | Status (2026-10-20) |
| --- | --- | --- | --- | --- |
| 1 | Cache the last verified tier and expiry (Keychain or UserDefaults). Seed `entitlementSnapshot` from it at launch as verified with a cached provenance; StoreKit corrects it later. | Actionable | Small | Done — `SubscriptionLease` + `EntitlementCache` seed a `.cached` verified snapshot at launch. |
| 2 | Wrap the `currentEntitlements` loop in a 3 s timeout. On timeout keep the cached tier instead of failing closed. | Actionable | Small | Done — `withDeadline` (`Deadline.swift`) returns at the timeout even when the stream ignores cancellation (1.5 s interactive, 3 s background). |
| 3 | Remove `fetchProducts()` from `init`. Call it from `PaywallView` and `ManagePlanView` with a "Prices unavailable offline" state. | Actionable | Trivial | Done — removed from `init`; `PurchaseViewModel.attach` loads products when a paywall or Manage Plan appears. |
| 4 | In `fetchImage`: set `resizeMode = .fast`, call `cancelImageRequest` on task cancellation, read `PHImageResultIsInCloudKey` and `PHImageResultErrorKey`, resume exactly once. | Actionable | Small | Done — `resizeMode = .fast`, in-cloud/error keys, resume-once, and `cancelImageRequest` via `withTaskCancellationHandler`. |
| 5 | In `AssetThumbnail`, show "Stored in iCloud — not available offline" instead of an endless spinner. | Actionable | Small | Done — `AssetThumbnail` shows a "Stored in iCloud" tile. |
| 6 | Show a visible offline error on the picker paths ("This photo isn't downloaded to your device"). | Actionable | Small | Done — picker, batch and Files paths show "isn't downloaded to your device" errors, gated by `ICloudDownloadPreference`. |
| 7 | Add an `NWPathMonitor` offline banner. | Speculative | Optional | Not started. |

## Follow-up questions and recommendation

- Is "Optimize iPhone Storage" on for iCloud Photos on the test phone? If so, cause 3 and 4 explain the missing screenshots.
- Is the slowness worst on cold launch or after backgrounding? Cold launch points to StoreKit; backgrounding points to the scene-activation entitlement refresh.
- Should an Instruments pass (Time Profiler plus Network) in Airplane Mode confirm cause 1 before patching?
- Premium promises Files/cloud import. Does it need a clear offline message, since iCloud Drive files can't be read offline?

**Recommendation:** make fixes 1–3 first, then 4 and 5 for screenshot loading. Build and test each in Xcode, since none has been compiled.
