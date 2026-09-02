# iPhoneUSBDisplay Development Log

## 2026-09-03 — Initialize Project Documentation and Git Conventions

### Summary

- Added the project collaboration guidelines and English-only documentation rules.
- Defined the required one-commit-per-change workflow and conditional commit-message sections.
- Recorded the initial empty-project state and outstanding setup work.

### Affected Files

- `AGENTS.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Reviewed the Markdown files for consistency with the requested workflow.
- Build and automated tests: Not run because no application or test targets exist yet.

### Remaining Risks or Follow-up Work

- Product requirements, supported platforms, architecture, source code, and tests remain to be defined.

## 2026-09-03 — Build the iPhone USB Display MVP

### Summary

- Added a native macOS 14+ SwiftUI application for discovering and displaying wired iPhone screen-capture devices through AVFoundation and CoreMediaIO.
- Added automatic single-device selection, multiple-device selection, last-selection restoration, reconnect handling, public permission handling, structured connection states, and bounded retries.
- Added a direct `AVCaptureVideoPreviewLayer` AppKit bridge with aspect-fit rendering, black letterboxing, native full screen, double-click full-screen toggling, pointer tracking, and balanced cursor hiding.
- Added a three-second connected-state control auto-hide policy and full-screen-only pointer hiding.
- Added Swift Testing coverage for device filtering, selection, reconnect state, retry invalidation and delays, error mapping, and auto-hide behavior.
- Added the local SwiftPM app-bundle build, signing, launch, logging, telemetry, verification, and Codex Run workflows.

### Affected Files

- `Package.swift`
- `.gitignore`
- `.codex/environments/environment.toml`
- `Sources/iPhoneUSBDisplay/`
- `Tests/iPhoneUSBDisplayTests/`
- `script/build_and_run.sh`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `xcrun swift-format lint --recursive Sources Tests Package.swift`: Passed with no warnings.
- `swift test --disable-sandbox -j 1`: Passed 14 tests across three suites.
- Debug build through `script/build_and_run.sh --verify`: Passed; the generated app bundle launched and its process was confirmed.
- `swift build --disable-sandbox -c release -j 1`: Passed.
- `plutil -lint dist/iPhoneUSBDisplay.app/Contents/Info.plist`: Passed.
- `codesign --verify --deep --strict --verbose=2 dist/iPhoneUSBDisplay.app`: Passed.
- Running-app visual check: Passed for the no-device state, required guidance, black canvas, custom full-screen entry and exit, double-click full-screen entry, and black full-screen presentation.
- USB iPhone capture, device names, permission prompting, rotation, disconnect/reconnect, occupied-device recovery, multiple physical devices, connected-state control hiding, 30-minute soak, frame rate, and latency: Not run because no suitable connected iPhone hardware was available.

### Remaining Risks or Follow-up Work

- Complete the outstanding single- and multiple-iPhone hardware acceptance matrix.
- Measure the 30-minute stability, incoming/display frame rate, and end-to-end latency targets on a capable Mac, iPhone, and USB cable.
- Confirm the external Apple USB muxed-device filter against the supported physical iPhone and macOS combinations.
- Production signing, notarization, App Store packaging, and distribution remain outside this local MVP.
