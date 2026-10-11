# AGENTS.md

## What this is

Pencil'd is a SwiftUI iOS application. The Xcode project is generated from [`project.yml`](project.yml); `Package.swift` also exposes the same app and test sources to SwiftPM/Xcode. Do not hand-edit generated project references as a substitute for updating the XcodeGen spec.

## Layout

- [`Sources/Pencild/`](Sources/Pencild/) — app entry point, models, persistence, services, view models, themes, and SwiftUI views.
- [`Tests/PencildTests/`](Tests/PencildTests/) — Swift Testing unit tests.
- [`Pencild.xcodeproj/`](Pencild.xcodeproj/) — generated Xcode project and shared `Pencild` scheme.
- [`Config/`](Config/) — Pencild Debug, Release, and base xcconfigs.
- [`Assets.xcassets/`](Assets.xcassets/) — app icon catalog and other assets; `Pencild.icon/` is the Icon Composer source.
- [`Pencild.storekit`](Pencild.storekit) — local StoreKit test catalog; live App Store Connect parity is not implied.
- [`pencild-design-system-updated.md`](pencild-design-system-updated.md) — design spec. Read before writing or changing UI; map its CSS token names to SwiftUI equivalents.
- `lancedb/` — local vector-store runtime data. Do not commit, delete, or rewrite it as part of ordinary source changes.

## Build, test, and commit checks

Install the repository's staged-file pre-commit brand check once per clone:

```sh
./scripts/install-hooks.sh
```

CI also runs the brand identity gate and its regression tests on every pull request and push to `main`.

```sh
xcodegen generate --spec project.yml
xcodebuild -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project Pencild.xcodeproj -scheme Pencild \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Use an available simulator destination from `xcrun simctl list devices available` if iPhone 17 is not installed. The app uses iOS-only APIs; prefer an iOS Simulator build/test over a macOS `swift build`.

## Language and design conventions

- Swift 6.4 tools, Swift 6 language settings, with `ApproachableConcurrency` enabled. Keep new code concurrency-safe.
- SwiftUI-first; no external Swift package dependencies are currently declared.
- Follow the design spec and existing component patterns. Preserve accessibility: at least 44pt touch targets; confidence states combine icon, label, and color.
- Preserve the current local-first processing and explicit review-before-save behavior. Do not add remote services, analytics, or account integrations without a separate approved task.
- Keep app, StoreKit, notification, and persistence identifiers coordinated across source, tests, `Pencild.storekit`, and project configuration.
