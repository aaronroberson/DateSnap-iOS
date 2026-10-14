# Pencil’d launch production-readiness plan

Date: 2026-10-14  
Source: [`2026-10-11-production-readiness-remediation-plan.md`](2026-10-11-production-readiness-remediation-plan.md)

## Scope and decisions

All 18 items currently listed under “Outstanding before release” are in the
launch scope. Repository changes, tests, release evidence, and release
runbooks are included here. App Store Connect, Apple Developer, and GitHub
account mutations require an explicit confirmation immediately before the
mutation. Read-only inspection and dry-run commands may proceed first.

Product decisions are fixed for this wave:

- Warn when one qualifying free scan remains.
- Request an App Store rating after the third successful save.
- Build trial disclosure from StoreKit `displayPrice` and the live offer
  period.
- Resume a blocked action after purchase when its source state is still valid.
- Defer `PurchaseIntent` until the ordinary purchase lifecycle is verified.
- Search the existing and proposed App Store keywords before choosing the
  final set; retain `camera`, `invite`, and `file` when the 100-character
  limit permits, otherwise select the stronger terms based on the search
  evidence and document the decision.

## The 18 launch items

### Apple and listing configuration

1. Sign in with Apple entitlement, organization-team signing, and device
   verification; otherwise hide the button for release.
2. Create and verify the Plus/Premium monthly and annual products, shared
   subscription group, one-week trials, and both lifetime products.
3. Schedule the manual retirement of lifetime products after 2027-04-13.
4. Decide and document the App Store keyword field.

### Device, sandbox, and runtime evidence

5. Verify Plus-member paywall behavior and lifetime-owner rebuy protection.
6. Verify entitlement retry during slow/offline StoreKit launch.
7. Complete the iPhone and iPad visual/runtime matrix.
8. Verify Calendar Add Events Only save behavior and explanatory Settings copy.
9. Exercise schedule extraction with representative real scheduling-app images.

### Product behavior and release creative

10. Add the rating prompt after the third successful save.
11. Add the one-scan-left Home warning state.
12. Build trial disclosure from live StoreKit values.
13. Add contextual paywall headlines for the triggering feature.
14. Resume a blocked action after a successful purchase where state is valid.
15. Produce the six-screenshot App Store set and work-schedules Custom Product
    Page assets.
16. Complete `PurchaseIntent` handling only after the standard purchase flow is
    verified.

### Repository and remote workflow

17. Add `.codebase-memory/` to `.gitignore` or the approved brand-gate
    exclusions, without committing its local index.
18. Confirm the GitHub Actions workflow is disabled remotely after inspecting
    the current local and remote state.
    
19. Update "CAPTURE - Create New Event" sheet/modal so that it has a matching background gradient as the other sheets/modals, , matching eyebrow color, font, and font size as well as positioning, restore the description below the title, Update the full width Screenshots tile to include the auto selected events display when applicable (same as the Home screen's Screenshots card) , make the 4 tiles after the Screenshots tile into a two column grid (2x2), superimpose the PREMIUM bandge over the top right corner of the PDF  & File import tile (extending beyond the top border of the tile) and change it's background to match the other three 2x tiles.

20. Update caputre event actions throughout the app to use the "CAPTURE - Create New Event" model/sheet instead of navigating to the home page (e.g. change all caught up button on the review screen to "Capture new event" instead of "Go to scanner", update scanner icon in top right of History & Archive to open the "Capture" sheet/modal, etc.)

## Execution sequence

### Phase 0 — Baseline and authorization gates

- Reconcile the current branch, worktree, source plan, audit, project
  generation inputs, bundle identifier, entitlements, StoreKit catalog, and
  workflow files.
- Build a source-of-truth matrix mapping each item to its owner, code seam,
  external dependency, and required evidence.
- Inspect GitHub workflow state with `gh` and report the exact proposed remote
  operation before asking for confirmation.
- Inspect Apple Developer/App Store Connect readiness without changing account
  state. Confirm the organization team, App ID, product group, territories,
  prices, and listing permissions before any mutation.

### Phase 1 — Repository safety and product behavior

- Add the local index exclusion through a narrow `.gitignore` change.
- Implement the one-scan warning, rating prompt, live trial disclosure,
  contextual paywall copy, and post-purchase action resumption with focused
  tests. Keep the local-first review-before-save invariant.
- Keep `PurchaseIntent` behind a separate, explicitly verified lifecycle slice;
  do not enable promoted products as a side effect of the other paywall work.
- Run focused unit tests after each bounded behavior batch and preserve
  result-bundle paths.

### Phase 2 — Account and StoreKit readiness

- Prepare the Sign in with Apple entitlement and organization-team signing
  changes only after the team/App ID facts are confirmed.
- Reconcile `Pencild.storekit` IDs and local behavior with the intended
  App Store Connect products. Report the exact product/group/offer mutations,
  then obtain confirmation before creating or editing them.
- Add the lifetime-product retirement date to the release runbook and listing
  decision record; the future retirement itself remains a manual operational
  action.

### Phase 3 — Verification environment and runtime matrix

- Establish the available Xcode simulator/device test path first; document what
  can be verified locally versus what needs a physical device, sandbox, or
  TestFlight.
- Help prepare Apple Developer/App Store Connect and TestFlight setup as a
  guided checklist, but do not claim device or TestFlight evidence until a
  signed build has been installed and exercised.
- Run the paywall member/lifetime-owner, entitlement retry, Add Events Only,
  visual iPhone/iPad, and scheduling-image scenarios.
- Capture screenshots, simulator identifiers, test result bundles, and any
  blocked external prerequisites.

### Phase 4 — Listing assets and remote workflow

- Perform the keyword search comparison for retained and replacement terms,
  then update the App Review notes and listing decision record together.
- Produce the six default screenshots and work-schedules Custom Product Page
  plan/assets, preserving the no-analytics and no-third-party-data boundary.
- After explicit confirmation, apply only the approved GitHub workflow change
  with `gh`, then verify the remote state independently.
- After explicit confirmation, perform approved App Store Connect and Apple
  Developer mutations, recording IDs, timestamps, and screenshots/evidence.

### Phase 5 — Release closeout

- Regenerate with XcodeGen from `project.yml`.
- Run Debug builds and full tests on the available iPhone and iPad
  destinations, then the Release build and release-content scan.
- Run brand, diff, legacy-literal, accessibility, Dynamic Type, Reduce Motion,
  VoiceOver, and 44-point target checks.
- Update the source remediation plan and audit with current repository-relative
  evidence. Mark an item complete only when its matching evidence is retained.

## Evidence and stop conditions

The final handoff must include the branch/HEAD, clean-worktree state, changed
files, decisions, blocked external prerequisites, command paths, simulator or
device identifiers, test result bundles, release artifact scan, and account
operation confirmations. A static workflow or StoreKit catalog is not evidence
that the remote workflow or App Store Connect products are configured.

Stop before any external mutation if the observed team, product IDs, workflow
state, or listing facts differ from the expected baseline. Report the mismatch
and request direction rather than broadening the change.

## Repository implementation status

Completed in the current launch wave:

- [x] One-scan-left Home warning, with truthful qualifying-scan copy.
- [x] Third-successful-save App Store review request, limited to once per app
      version and deferred until the success flow settles.
- [x] StoreKit-backed trial disclosure using the selected product's live
      `displayPrice` and introductory-offer period.
- [x] Contextual paywall headline transport for feature-triggered paywalls.
- [x] Preserve gated screenshot-triage filter intent across a successful
      purchase; broader source-specific action resumption still requires
      runtime verification.
- [x] Preserve a locked PDF & Files import request across Premium purchase;
      cancellation leaves the importer closed.
- [x] Route Batch Review's locked-feature upgrade affordance through the
      contextual paywall transport; rerunning retained skipped source images
      still requires a separate runtime/source-state slice.
- [x] Capture/Create New Event sheet redesign (item 19).
- [x] Capture actions routed through the shared sheet (item 20).
- [x] `.codebase-memory/` excluded from the repository.
- [x] Added the April 14, 2027 lifetime-product retirement procedure to
      `docs/runbooks/RELEASE.md`; the App Store Connect operation itself
      remains confirmation-gated and future-dated.
- [x] The current 95-character keyword field retains `camera`, `invite`, and
      `file`, so the requested terms fit without replacing another keyword.

Still requiring external setup or stronger runtime evidence:

- [ ] Apple organization team, Sign in with Apple capability, App Store
      products, TestFlight/device setup, real scheduling-app images, listing
      screenshots, and Custom Product Page assets.
- [ ] Remote GitHub Actions state. `gh workflow list --all` was attempted on
      2026-10-14 but the GitHub API was unreachable; no mutation was made.
- [ ] Full Xcode build/runtime evidence. `xcodegen generate --spec project.yml`
      completed successfully. The app-icon configuration now targets the
      existing `AppIcon.appiconset` and excludes the invalid root
      `Pencild.icon` resource. The three referenced iOS icon images were
      replaced with the matching Icon Composer exports, and a direct `actool`
      compile passed. The generic iOS build now passes asset compilation and
      reaches Swift compilation, but the host's Swift plugin
      server returns malformed responses for built-in `SwiftUI`, `SwiftData`,
      and `FoundationModels` macros; no repository source error was isolated.
- [ ] Runtime verification for post-purchase resumption. Repository behavior
      now covers Home batch state, PDF & Files import, screenshot-triage
      filters, and Batch Review's retained locked screenshots; device-level
      purchase/cancellation verification remains outstanding.
- [x] Added a focused `ScheduleGatingTests.batchRetryAfterUpgrade` regression
      test for retained locked batch screenshots; test execution remains
      blocked by the host Swift macro-plugin failure after asset compilation.
- [ ] `PurchaseIntent`, intentionally deferred until ordinary purchase flow
      verification.
