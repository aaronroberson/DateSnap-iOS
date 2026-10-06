# DateSnap-iOS — Round 34j Closure & Gate Hardening

**Work performed:** 2026-10-04 01:39 – 02:20 PDT
**Document regenerated:** 2026-10-05 11:36 PDT (clipboard was lost; nothing else was)
**Repo:** `/Users/conscious/apps/DateSnap-iOS` · branch `main`

---

## Summary

Fail-open is fixed and committed, and the next gate is **complete** — a real Release binary was built and the scan passed against it — but the build surfaced a measured blind spot in that gate and a pre-existing allowlist row that is factually wrong.

---

## Insights

### Fail-open closed — `d6f6fd4` (Supported, tested both directions)

`verify-no-mock.sh` no longer swallows rg failures: exit ≥2 is fatal, and a new preflight canary requires each regex construct to actually match a probe before a zero-hit result is trusted.

Verified by running it both ways:

| condition | result |
|---|---|
| non-PCRE2 `rg` (the old false-green case) | **exit 3**, loud diagnosis |
| PCRE2-capable `rg` | **exit 0**, 31 allowlisted |

The same bug existed in `verify-release-content.sh` and was fixed there too:

- rg error vs. no-match conflation in both the source and binary scans — an error is now fatal instead of printing "scan passed"
- `strings` failure or empty output is now fatal rather than a silent pass
- new `--require-app` flag (or `DATESNAP_REQUIRE_APP=1`) stops the release path from exiting 0 on source-only verification

### Your Mac confirms it without any shim (Supported)

`rg 15.2.0` has `+pcre2` (PCRE2 10.45, JIT), so the fix doesn't break you — and the native run gives **0 unallowlisted / 31 allowlisted**, which independently validates the shimmed result obtained earlier in the sandbox.

All three gates green natively:

| gate | exit | result |
|---|---|---|
| `verify-no-mock.sh` | 0 | 0 unallowlisted / 31 allowlisted |
| `verify-recovery.sh` | 0 | nothing modified |
| `verify-release-content.sh --require-app` | 0 | passed across **57,710 strings** |

### The next gate is genuinely complete (Supported)

Built with Xcode 27, Release configuration, `Release-iphonesimulator`, `CODE_SIGNING_ALLOWED=NO`.

Binary-level proof the DEBUG gating survives compilation — from 69,080 symbols:

| symbol / string | Release binary |
|---|---|
| `ScreenGalleryView` | **absent** |
| `InterpretationDiagnosticsView` | **absent** |
| `sampleNeonSunset`, `sampleDentalCheckup`, `rawOcrFragments` | **absent** |
| `Screen State & Simulation Hub` | **absent** |
| `All 17 Stitch Screens` | **absent** |
| `Neon Sunset Rooftop Session` | **absent** |
| `Mock*Service` symbols | **0** |

That retires the ScreenGalleryView release-reachability follow-up at the strongest available level.

### New finding — the binary scan has a ≤15-byte blind spot (Supported, measured not theorised)

Swift stores string literals of ≤15 UTF-8 bytes as immediates, so they never reach the string table and `strings` cannot see them. The byte-length ladder is unambiguous:

| literal | bytes | in `strings` |
|---|---|---|
| `Privacy Center` | 14 | absent |
| `CFBundleVersion` | 15 | absent |
| `Reminder Preview` | 16 | **present** |
| `Support & System` | 16 | **present** |

**Consequence:** `release_forbidden`'s own entry `Stitch ID:` (10 bytes) is *structurally undetectable* by this method — it can never fail, which is worse than failing. `SUMMIT_2025.PDF` (15 bytes) is likewise invisible.

Secondary blind spot: `strings` fragments on non-ASCII, so a marker containing the `·` in the paywall copy is only ever seen in pieces.

The gate is sound for the long markers and blind for the short ones. A symbol-table assertion — the method that proved `ScreenGalleryView` is gone — is the fix.

---

## Caveats / Contradictions

### Open item needing your verdict — nothing was changed

Three **pre-existing** allowlist rows claim `SampleFlyer.swift` is `DEBUG-gated sample content (PR #19/#22 release gating)`. The evidence says otherwise:

- `SampleFlyer.swift` contains **zero** `#if` directives in 59 lines
- `HomeEmptyStateView.swift:392-395` — the "Try Sample Flyer" button, under "Curious how it works?" — sits **outside** the `#if DEBUG` block that opens at line 420, so it ships
- `ScanViewModel.swift:97` `scanSampleFlyer()` is public, not gated, doc-commented *"needs no photo permissions"*
- the Release binary carries `SKYBAR PENTHOUSE`, `8440 SUNSET BLVD, WEST HOLLYWOOD, CA`, `Try Sample Flyer`, and asset id `datesnap-sample-flyer` (×2)
- `release_forbidden` **deliberately omits** `datesnap-sample`, so the release gate was authored expecting this to ship

**Reading:** an intentional onboarding feature with a false audit reason — not a leak. The round-34j handoff inherited the same false claim.

Correcting another round's adjudication, and characterising a product decision, is your call rather than mine, so the rows were left untouched. Proposed replacement reason for all three:

```
intentional shipped onboarding sample (Try Sample Flyer, HomeEmptyStateView:392);
NOT DEBUG-gated; datesnap-sample-* deliberately absent from release_forbidden
```

**Status as of 2026-10-05 11:36 — still unchanged** (`scripts/mock-allowlist.txt` lines 11-13).

### Other notes

- The report was kept in `/tmp`, not the repo, on purpose: when an earlier copy sat in the repo root, the now-working scanner correctly flagged its own report for containing marker words. `docs/**` is glob-excluded, so `docs/` is a safe home for it.
- A simulator Release build proves the preprocessor gating but not the device archive path.
- `/tmp/ds-rel-dd` derived data is still on the Mac and can be cleared.

---

## State change since the work was done

| | 2026-10-04 02:20 | 2026-10-05 11:36 |
|---|---|---|
| `HEAD` | `d6f6fd4` (1 ahead) | `2066ac5` |
| vs `origin/main` | 1 ahead / 0 behind | **0 ahead / 0 behind — synced** |
| SampleFlyer rows | open | **still open** |

`d6f6fd4` was pushed. Three further commits landed since: `804a84b` (inject deterministic calendar), `7933e45` (configure physical-device team), `2066ac5` (use certificate team identifier) — i.e. the work moved on to device signing, which is the natural precursor to the device-archive gate below.

---

## Next steps

1. **Rule on SampleFlyer** *(Actionable, smallest unblock)* — the audit trail currently misstates what ships. Approve the replacement reason above and it becomes one commit.
2. **Close the ≤15-byte blind spot** *(Actionable, highest durable value)* — add a symbol-table assertion to `verify-release-content.sh` via `nm`, so short markers like `Stitch ID:` are checked by symbol rather than by `strings`. Without it, one of the gate's own 14 forbidden patterns silently cannot fire.
3. **Wire `--require-app` into the archive step** *(Actionable)* — `docs/runbooks/RELEASE.md:57` describes the binary scan as blocking but cannot enforce it. Now that signing is configured, a real `xcodebuild archive` would also exercise signing and stripping, which the simulator build does not.
4. **Sweep for the same bug class** *(Actionable, cheap insurance)* — grep `scripts/` for `|| true` and bare `if rg`; the error-as-pass pattern appeared in two of three scripts, so a third is plausible.
5. **Tidy** *(Low priority)* — `docs/prompts/datesnap-round34j-handoff.md` is untracked; commit it as the round's record or gitignore it. Clear `/tmp/ds-rel-dd`.

### Overlooked / suggested follow-ups

- How long was the mock gate failing open? `git log -p scripts/verify-no-mock.sh` dates when `-P` was introduced and bounds how many rounds certified nothing.
- The new AppIcon assets are modified/untracked (`DateSnap-AppIcon-1024*.png`, plus `.swiftpm/`) — worth a deliberate commit or ignore before the next release pass.
- `SUMMIT_2025.PDF` remains the one sample-title token that reaches users. Defensible as paywall illustration, but a reviewer scanning for placeholder content could flag it.

---

## Appendix A — raw closure report (generated 2026-10-04 02:18:40 PDT)

This is the content that was on the clipboard.

```text
# DATESNAP-iOS CLOSURE REPORT - 2026-10-04 02:18:40 PDT
# repo: /Users/conscious/apps/DateSnap-iOS  branch: main

## COMMITS (full hashes)
d6f6fd4758cc9e79c5e36a42b4d7b883c030918c  d6f6fd4  2026-10-04  fix(verify): close fail-open in mock-marker and release-content gates
02596df74a5ad1fcfc2bd1443290c20647baf163  02596df  2026-10-04  docs(audits): archive 2026-10-04 generated full audit report (40,528 lines)
1925e6c08cd867b2fe1badc306d1e73ae86a27bf  1925e6c  2026-10-04  chore(verify): allowlist final four adjudicated markers (DEBUG-gated fixtures, intentional demo copy, internal design gallery)
066c83ff67be1620182b1a2c338d767553e8a3e6  066c83f  2026-10-04  chore(verify): adjudicate remaining markers - allowlist doc-comment price example and stitch tooling
e949da88dc06f9cf317d2223c2f97231ce7785c7  e949da8  2026-10-04  chore(verify): scope mock-marker scan to production source; allowlist test fixtures and DEBUG-gated SampleFlyer
9c91b6a90d23e084bbe7ba9f0e197a8645ba9dc6  9c91b6a  2026-10-04  chore(verify): exclude .stitch design mockups from mock-marker scan
a346914f294493e87a5ee34cb1f6309549a96957  a346914  2026-10-04  chore(verify): restrict mock-marker scan to source; exclude docs prose
5302af37e553642483251afed770378171c431ae  5302af3  2026-10-04  Merge pull request #25 from aaronroberson/jules-6145641643509236244-9d9064fb

## HEAD / REMOTE
HEAD        d6f6fd4758cc9e79c5e36a42b4d7b883c030918c
origin/main 02596df74a5ad1fcfc2bd1443290c20647baf163
ahead 1 / behind 0

## TAGS (tag object -> target commit)
archive/preview-recovery-line    4d7e90332a8c1b4693e6ed796953d08306bf42be -> 243efed5bab059fb6385b6e4e1969e98f55dfd68  docs(recovery): record preview merge + push authorization (addendum)
recovery-integrated-20261002     9b8f0aa62f4bf59e43cc4e88ee39b343ae1ff79d -> 02596df74a5ad1fcfc2bd1443290c20647baf163  docs(audits): archive 2026-10-04 generated full audit report (40,528 lines)

## WORKTREES
/Users/conscious/apps/DateSnap-iOS d6f6fd4 [main]

## GAUNTLET (native, Homebrew rg 15.2.0 with PCRE2)
verify-no-mock.sh          EXIT=0 | No unallowlisted mock or stale-state markers found (31 allowlisted hits).
verify-recovery.sh         EXIT=0 | === Done. Nothing modified.
verify-release-content.sh  EXIT=0 | Release-content verification passed.  (--require-app, Release .app)
  strings scanned: scanned 57710 strings

## RELEASE BINARY EVIDENCE (Release-iphonesimulator, CODE_SIGNING_ALLOWED=NO)
symbols=69080  strings=57710
DEBUG types stripped from Release:
  ScreenGalleryView                ABSENT
  InterpretationDiagnosticsView    ABSENT
  sampleNeonSunset                 ABSENT
  sampleDentalCheckup              ABSENT
  rawOcrFragments                  ABSENT
DEBUG UI copy stripped from Release:
  Screen State & Simulation Hub    ABSENT
  All 17 Stitch Screens            ABSENT
  Neon Sunset Rooftop Session      ABSENT

## GATE BLIND SPOT (measured, not theorised)
Swift stores string literals <=15 UTF-8 bytes as immediates, so they never
reach the string table and 'strings' cannot see them. Byte-length ladder:
  14B 'Privacy Center'    -> absent    15B 'CFBundleVersion' -> absent
  16B 'Reminder Preview'  -> PRESENT   16B 'Support & System'-> PRESENT
Consequence: release_forbidden entry 'Stitch ID:' (10B) is structurally
undetectable by the binary scan, as is 'SUMMIT_2025.PDF' (15B).
Also: 'strings' fragments on non-ASCII, so a marker containing a middle dot
or dash is seen only as fragments.

## OPEN ITEM FOR AARON (needs your verdict - NOT changed by me)
Three pre-existing allowlist rows claim SampleFlyer.swift is DEBUG-gated:
  mock-prefix|*SampleFlyer.swift|*|aaron|DEBUG-gated sample content (PR #19/#22 release gating)
  (+ sample-title and simulation-copy rows with the same reason)
Evidence says it is NOT DEBUG-gated and ships intentionally:
  - SampleFlyer.swift contains zero #if directives (59 lines)
  - HomeEmptyStateView.swift:392-395 'Try Sample Flyer' button is OUTSIDE
    the #if DEBUG block (which opens at 420) -> it ships
  - ScanViewModel.swift:97 scanSampleFlyer() is public, not DEBUG-gated,
    doc-comment: 'needs no photo permissions'
  - Release binary contains 'SKYBAR PENTHOUSE', '8440 SUNSET BLVD...',
    'Try Sample Flyer', and asset id 'datesnap-sample-flyer' (x2)
  - release_forbidden deliberately does NOT list datesnap-sample, so the
    release gate was authored expecting this to ship
Read: an intentional onboarding feature with a FALSE allowlist reason.
Proposed reason (replacing 'DEBUG-gated sample content' on all three rows):
  intentional shipped onboarding sample (Try Sample Flyer, HomeEmptyStateView:392);
  NOT DEBUG-gated; datesnap-sample-* deliberately absent from release_forbidden
```

---

## Appendix B — reproducing this

The generator survived at `/tmp/ds-closure-report.sh` on the Mac and is re-runnable:

```sh
/tmp/ds-closure-report.sh | pbcopy          # uses the existing Release .app
/tmp/ds-closure-report.sh /path/to/Other.app
```

Rebuilding the Release `.app` from scratch:

```sh
cd /Users/conscious/apps/DateSnap-iOS
xcodebuild -project DateSnap.xcodeproj -scheme DateSnap \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/ds-rel-dd \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

bash scripts/verify-release-content.sh --require-app \
  /tmp/ds-rel-dd/Build/Products/Release-iphonesimulator/DateSnap.app
```
