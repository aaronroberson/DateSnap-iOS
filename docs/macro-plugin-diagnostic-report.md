# Macro Plugin & Toolchain Diagnostic Report

**Project**: Pencil’d  
**Platform**: iOS  
**Target Scheme**: Pencild  

---

## 1. Toolchain & Environment Verification

| Component | Detected Version / Path |
| :--- | :--- |
| **Xcode Version** | Xcode 27.0 (Build `27A266a`) |
| **Active Developer Path** | `/Applications/Xcode.app/Contents/Developer` |
| **Command Line Tools (`xcode-select -p`)** | `/Applications/Xcode.app/Contents/Developer` |
| **Active iOS SDK** | iOS 27.0 (`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`) |
| **Swift Compiler** | Apple Swift version 6.4 (`swiftlang-6.4.0.34.1 clang-2100.3.34.1`, `swift-driver 1.168.6`) |
| **Host Target Architecture** | `arm64-apple-macosx26.0` |

---

## 2. Macro Plugin Availability

All required macro dylibs and the plugin daemon binary were verified present in the active Xcode installation:

- **Plugin Server Daemon**:  
  `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-plugin-server`
- **SwiftData Macro (`@Model`)**:  
  `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/swift/host/plugins/libSwiftDataMacros.dylib`
- **SwiftUI Macro (`@State`)**:  
  `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib`
- **FoundationModels Macro (`@Generable`)**:  
  `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/swift/host/plugins/libFoundationModelsMacros.dylib`

---

## 3. Primary vs. Cascading Diagnostics

- **Primary Diagnostic**:
  - `swift-plugin-server produced malformed response` / `...Macro could not be found`
  - Swift macros run out-of-process via IPC with `swift-plugin-server`. When building outside Xcode (e.g., standard `swift build` without iOS platform plugin paths or when a stale server process locks an IPC socket), `swift-plugin-server` crashes, disconnects, or fails to resolve the host plugins.
- **Cascading Diagnostics**:
  - `EventCandidate does not conform to PersistentModel`: `@Model` synthesizes the `PersistentModel` protocol conformance and backing fields. Because the macro failed to expand, the class appears incomplete.
  - `@State properties cannot be mutated`: SwiftUI’s `@State` macro synthesizes backing storage wrappers. Without macro expansion, state variables behave as normal immutable view properties.
  - `Foundation Models Generable/respond errors`: `@Generable` synthesizes schema serialization required by `.respond`.

> **Note**: Do not rewrite or remove `@Model`, `@State`, or `@Generable` in application code. The source annotations are completely valid; modifying them will only mask the underlying macro server issue.

---

## 4. Recommended Xcode UI Recovery Sequence

1. **Quit Xcode & Simulator**: Close Xcode and the iOS Simulator completely.
2. **Verify Command Line Tools in Xcode**: Go to **Xcode → Settings → Locations** (`Cmd + ,`). Ensure the **Command Line Tools** dropdown is set to **`Xcode 27.0 (27A266a)`** (not empty or pointing to a standalone CLI package at `/Library/Developer/CommandLineTools`).
3. **Clean the Build Folder**: Reopen the project in Xcode and choose **Product → Clean Build Folder** (`Cmd + Shift + K`).
4. **Delete DerivedData**: In **Xcode Settings → Locations**, click the arrow next to the **Derived Data** path and remove the `Pencild` folder (or purge `~/Library/Developer/Xcode/DerivedData/Pencild-*`).
5. **Build Against Generic iOS Device**: Select the destination **Any iOS Device (arm64)** from the run destination menu, then build with **Product → Build** (`Cmd + B`). This isolates compilation from local simulator daemon communication issues.
6. **Reboot (if needed)**: If `swift-plugin-server` persists in producing malformed responses, restart macOS to flush stale Mach IPC ports and orphan compiler helper processes.

---

## 5. Post-Recovery Build Status

The Xcode build environment has been verified directly via the build system:
- **Build Result**: `The project built successfully.` (0 errors, 0 warnings).
- **Unit Tests**: Targeted tests in `CalendarServiceTests` and `ScheduleConflictAnalyzerTests` pass.
- **Remaining Non-Cascading Errors**: **None.** The codebase compiles cleanly once Xcode's macro runtime is utilized.
