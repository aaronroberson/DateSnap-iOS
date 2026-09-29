# AGENTS.md

## What this is

DateSnap — an early-stage SwiftUI iOS app (currently a prototype skeleton: an `@main` App and one placeholder `ContentView`). It is a pure Swift Package with **no `.xcodeproj`**; Xcode works by opening `Package.swift` directly.

## Layout

- `Sources/DateSnap/` — the single executable target (`DateSnap.swift` is `@main`).
- `datesnap-design-system-updated.md` — the design spec. **Read this before writing or changing any UI.**
- `lancedb/` — local LanceDB vector-store data at the repo root. Runtime data, not source: don't commit it or delete it (it is not currently gitignored).
- Repo has no initial commit yet; everything is untracked.

## Build & run

```sh
swift build          # works today (SwiftUI-only code compiles against macOS)
xcodebuild -scheme DateSnap -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- Once iOS-only APIs (UIKit, VisionKit, etc.) are introduced, `swift build` on macOS will stop working — use `xcodebuild` with an iOS Simulator destination, or open `Package.swift` in Xcode and run on a simulator.
- No tests, no linter config, no CI yet.

## Language & toolchain

- Swift 6.4 toolchain with upcoming feature `ApproachableConcurrency` enabled (see `Package.swift`) — write concurrency-safe code (`Sendable`, structured concurrency) accordingly.
- SwiftUI-first; no external dependencies declared yet.
- The design doc is written with CSS-variable token names — map them to SwiftUI equivalents (color/gradient/material modifiers), don't paste CSS.

## Design rules (from datesnap-design-system-updated.md)

- Dark navy glassmorphism: background `#050816` (never pure black), translucent "glass" cards, luminous accent gradients. Semantic tokens (primary `#7CFFEA`, accent `#FF4FB3`, etc.) are defined in the doc.
- Display-P3 colors with sRGB fallback; fonts: Sora for display, Inter for UI.
- Accessibility: min 44pt touch targets; confidence states must combine icon + label + color, never color alone.
- The doc's "Component Mapping to SwiftUI" table gives the intended SwiftUI pattern per component — follow it rather than inventing styles.
