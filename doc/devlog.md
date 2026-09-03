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

## 2026-09-03 — Fix Physical iPhone Discovery

### Summary

- Diagnosed a connected physical iPhone that macOS and other capture applications could discover while iPhoneUSBDisplay showed no device.
- Confirmed that AVFoundation exposed the Apple external muxed screen source without occupation, but reported its transport type as `Other` instead of USB.
- Removed the unreliable strict USB transport comparison from the device filter while retaining external, Apple, and muxed-media requirements and keeping wireless screen discovery disabled.
- Rebuilt and launched the application, then confirmed that it displayed the connected device name, connected status, and live portrait screen.

### Affected Files

- `Sources/iPhoneUSBDisplay/Models/DisplayDevice.swift`
- `Sources/iPhoneUSBDisplay/Services/CaptureCoordinator.swift`
- `Tests/iPhoneUSBDisplayTests/DeviceSelectionTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- macOS device inspection: Passed; the physical iPhone was connected and its AVFoundation screen source was external, Apple-manufactured, muxed, not suspended, and not occupied by another application.
- `xcrun swift-format lint --recursive Sources Tests Package.swift`: Passed with no warnings.
- `swift test --disable-sandbox -j 1`: Passed 14 tests across three suites.
- `script/build_and_run.sh --verify`: Passed; the fixed app bundle was rebuilt, ad-hoc signed, launched, and its process was confirmed.
- Running-app hardware check: Passed; the app showed the connected iPhone name, green connected status, and live portrait screen content.
- `swift build --disable-sandbox -c release -j 1`: Passed.

### Remaining Risks or Follow-up Work

- Camera permission denial, orientation changes, hot unplug/replug, occupied-device recovery, and connected-state control hiding remain to be hardware-validated.
- Multiple-device behavior still requires two physical iPhones.
- The 30-minute soak, frame-rate measurement, and end-to-end latency measurement remain to be run.

## 2026-09-03 — Add Low-Latency Multi-Device Interface

### Summary

- Renamed the user-visible application to USB Display while preserving its executable and bundle identifier.
- Generalized discovery, status text, permission text, and selection behavior for USB-connected iPhone and iPad screen sources.
- Replaced the direct preview layer with a discard-late video data output and immediate AVSampleBufferDisplayLayer rendering path.
- Added stream-generation invalidation, display-layer backpressure, flush recovery, and aggregate frame timing telemetry.
- Rebuilt the main window with a native device sidebar, unified toolbar, black media canvas, and automatic full-screen sidebar restoration.
- Added native Liquid Glass full-screen controls for macOS 26+ with a regular-material fallback for macOS 14–15.
- Updated the generated bundle to version 0.2.0 while preserving its existing path and bundle identifier for camera-permission continuity.

### Affected Files

- Sources/iPhoneUSBDisplay/App/iPhoneUSBDisplayApp.swift
- Sources/iPhoneUSBDisplay/Models/
- Sources/iPhoneUSBDisplay/Services/
- Sources/iPhoneUSBDisplay/Support/AppLogger.swift
- Sources/iPhoneUSBDisplay/Views/
- Tests/iPhoneUSBDisplayTests/
- script/build_and_run.sh
- doc/current.md
- doc/devlog.md

### Validation

- xcrun swift-format lint --recursive Sources Tests Package.swift: Passed with no warnings.
- swift test --disable-sandbox -j 1: Passed 20 tests across four suites.
- swift build --disable-sandbox -c release -j 1: Passed.
- script/build_and_run.sh --verify: Passed; the version 0.2.0 app bundle was built, signed, launched, and its process was confirmed.
- plutil -lint dist/iPhoneUSBDisplay.app/Contents/Info.plist: Passed.
- codesign --verify --deep --strict --verbose=2 dist/iPhoneUSBDisplay.app: Passed.
- Generated bundle cleanup: Passed; only the stable dist/iPhoneUSBDisplay.app path remains.
- Running-app visual and live-frame check: Not run because the Mac was locked and the desktop automation service could not unlock it.
- Two-device hardware switching, 30-minute soak, sustained frame rate, and 240 fps latency comparison: Not run.

### Remaining Risks or Follow-up Work

- Verify live iPhone and iPad frames through the new renderer after unlocking the Mac.
- Verify the macOS 27 Liquid Glass appearance, sidebar resizing and selection, and full-screen collapse and restoration.
- Complete the two-device, rotation, hot-plug, occupied-device, performance, and stability hardware matrix.

## 2026-09-03 — Restore Compatible Mobile Device Preview

### Summary

- Diagnosed the connected iPad failure as AVFoundation error -11800 with underlying CoreMediaIO status !dev and an iOSScreenCaptureAssistant invalid-stream state.
- Confirmed that requesting device-native AVCaptureVideoDataOutput samples did not resolve the physical mobile screen-source failure.
- Removed the incompatible sample-buffer output and renderer path and restored the previously hardware-validated AVCaptureVideoPreviewLayer direct-preview path.
- Added a short session-stability gate so an immediate runtime error cannot reset retry backoff by briefly reporting the session as connected.
- Added a device-unavailable state with actionable unlock, competing-application, and USB reconnection guidance.
- Expanded structured error logs to include AVFoundation and underlying OSStatus domains and codes without logging device identifiers.

### Affected Files

- .gitignore
- Sources/iPhoneUSBDisplay/Models/CaptureFailure.swift
- Sources/iPhoneUSBDisplay/Models/ConnectionStatus.swift
- Sources/iPhoneUSBDisplay/Models/FrameRenderingPolicy.swift
- Sources/iPhoneUSBDisplay/Services/AppModel.swift
- Sources/iPhoneUSBDisplay/Services/CaptureCoordinator.swift
- Sources/iPhoneUSBDisplay/Services/SampleBufferRenderer.swift
- Sources/iPhoneUSBDisplay/Views/DisplayCanvasView.swift
- Sources/iPhoneUSBDisplay/Views/PreviewView.swift
- Sources/iPhoneUSBDisplay/Views/SidebarView.swift
- Tests/iPhoneUSBDisplayTests/CaptureFailureTests.swift
- Tests/iPhoneUSBDisplayTests/FrameRenderingPolicyTests.swift
- doc/current.md
- doc/devlog.md

### Validation

- CoreMediaIO and AVFoundation diagnostics: Passed; captured AVFoundation error -11800, underlying OSStatus 560227702, and the iOSScreenCaptureAssistant invalid-state report.
- xcrun swift-format lint --recursive Sources Tests Package.swift: Passed with no warnings.
- swift test --disable-sandbox -j 1 using project-local module caches: Passed 16 tests across three suites.
- Release build: Passed.
- script/build_and_run.sh --verify: Passed; the rebuilt app bundle launched and its process was confirmed.
- Connected-iPad discovery and device name: Passed.
- Connected-iPad live preview after restoring the direct-preview path: Not run successfully because the current system capture assistant continued rejecting the device stream; the iPad and competing capture applications require a physical reset before revalidation.

### Remaining Risks or Follow-up Work

- Unlock the iPad, close QuickTime and Screen Studio, reconnect the USB cable, and revalidate live preview.
- Re-run portrait and landscape rotation, hot-plug, device switching, 30-minute stability, frame-rate, and external latency checks after the device stream recovers.

## 2026-09-03 — Migrate to Xcode and Add Capture Quality Selection

### Summary

- Replaced the SwiftPM executable package with a standard Xcode macOS application project containing an app target, unit-test target, and shared scheme.
- Added project-owned Info.plist metadata and a camera-device entitlement while preserving the `com.xuemingbo.iPhoneUSBDisplay` bundle identifier.
- Updated the local build/run workflow to build and launch the Xcode application product from project-local DerivedData instead of manually constructing an app bundle.
- Removed the obsolete Package.swift file, generated .swiftpm workspace, and manually staged dist application.
- Added persistent Auto, 1080p, and 4K (Experimental) quality choices to the native toolbar and full-screen control surface.
- Added supported-preset fallback logic and structured logging for requested quality, applied preset, public format dimensions, and public maximum frame rate.
- Added unit tests for quality preference and fallback behavior.

### Affected Files

- `.codex/environments/environment.toml`
- `.gitignore`
- `Config/Info.plist`
- `Config/USBDisplay.entitlements`
- `Package.swift`
- `USBDisplay/`
- `USBDisplayTests/`
- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay.xcodeproj/xcshareddata/xcschemes/USB Display.xcscheme`
- `script/build_and_run.sh`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `plutil -lint Config/Info.plist Config/USBDisplay.entitlements`: Passed.
- `xcodebuild -list -project USBDisplay.xcodeproj`: Passed; reported the `USB Display` app target, `iPhoneUSBDisplayTests` test target, and `USB Display` scheme.
- `xcrun swift-format lint --recursive USBDisplay USBDisplayTests`: Passed with no warnings after formatting.
- Xcode Debug build with project-local DerivedData: Passed.
- Xcode Release build with project-local DerivedData: Passed.
- Xcode unit tests: Passed 19 tests across four suites.
- `script/build_and_run.sh --verify`: Passed; built and launched the standard Xcode `USB Display.app` product and confirmed the process.
- Built Info.plist inspection: Passed; confirmed version `0.3.0`, build `3`, macOS `14.0`, the unchanged bundle identifier, high-resolution capability, and the USB mobile-screen permission explanation.
- `codesign --verify --deep --strict --verbose=2`: Passed for the Debug application.
- Built entitlement inspection: Passed; confirmed `com.apple.security.device.camera` and the local Debug `get-task-allow` entitlement.
- Running-app check on macOS 27: Passed; the Xcode-built application displayed a live iPad screen, switched to a live iPhone screen, and switched back to the iPad while remaining connected.
- Auto quality check: Passed; the live iPad session applied `AVCaptureSessionPresetHigh`, started, and remained connected.
- 1080p quality check: Passed; the live iPad session applied `AVCaptureSessionPreset1920x1080`, started, and remained connected.
- 4K quality check: Passed; the live iPad session applied `AVCaptureSessionPreset3840x2160`, started, and remained connected.
- Visual quality comparison: No obvious sharpness difference was observed between the three presets at the tested window size.
- Public source-format inspection: Both connected mobile devices continued to report `0 x 0` dimensions and no frame-rate range, and the Apple capture helper exposed no usable stream-dimension telemetry.
- End-to-end latency measurement: Not run because it requires an external high-speed visual reference; session stabilization timing was not treated as capture latency.

### Remaining Risks or Follow-up Work

- Use a static resolution chart and external pixel-level capture before claiming that the accepted 1080p or 4K preset increases the native USB source resolution.
- Measure end-to-end latency with a 240 fps external camera and compare the three quality settings under the same device and cable conditions.
- Run the 30-minute stability test, sustained frame-rate measurement, rotation, hot-plug, occupied-device recovery, and macOS 14–15 fallback checks.
- Install a valid Apple Development signing identity if stable development signing and hardened Debug runtime are required.

## 2026-09-03 — Add Per-Device Windows and Simplify the Display UI

### Summary

- Replaced the single global capture model with an application-level device catalog and one independent capture model and `AVCaptureSession` per device window.
- Added a typed, device-ID-based `WindowGroup`, device-window routing, and ownership tracking so each device opens or focuses at most one window.
- Removed Auto, 1080p, and 4K choices, saved quality preferences, preset selection, and the associated menu and tests because accepted presets do not establish the source stream resolution.
- Removed custom connection, quality, pointer-hiding, and full-screen control overlays while retaining native window controls and the system sidebar toggle.
- Reduced the sidebar to device names and selection state and kept it below the title bar and separate from the display area.
- Added a proportional display viewport with system-background whitespace, a 16-point inset, clipping, and live aspect-ratio updates from the direct preview layer.
- Kept device names as hidden logical window titles for accessibility and Window menu identification.
- Added unit coverage for first-window assignment, per-device window reuse, ownership, invalid aspect ratios, and portrait and landscape fitting.
- Documented that the current public preview path does not provide reliable resolution selection or latency control.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Models/CaptureQuality.swift`
- `USBDisplay/Models/ConnectionStatus.swift`
- `USBDisplay/Models/ControlAutoHidePolicy.swift`
- `USBDisplay/Models/DeviceWindowRoutingPolicy.swift`
- `USBDisplay/Models/DisplayDevice.swift`
- `USBDisplay/Models/PreviewLayoutPolicy.swift`
- `USBDisplay/Services/AppModel.swift`
- `USBDisplay/Services/CaptureCoordinator.swift`
- `USBDisplay/Services/DeviceCatalog.swift`
- `USBDisplay/Views/CaptureQualityMenu.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/DisplayWindowScene.swift`
- `USBDisplay/Views/PreviewView.swift`
- `USBDisplay/Views/SidebarView.swift`
- `USBDisplayTests/CaptureQualityTests.swift`
- `USBDisplayTests/ControlAutoHidePolicyTests.swift`
- `USBDisplayTests/DeviceSelectionTests.swift`
- `USBDisplayTests/DeviceWindowRoutingTests.swift`
- `USBDisplayTests/PreviewLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `xcrun swift-format lint --recursive USBDisplay USBDisplayTests`: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: Passed 15 tests across four suites.
- `script/build_and_run.sh --verify`: Passed; built and launched the application and confirmed the process.
- `plutil -lint USBDisplay.xcodeproj/project.pbxproj Config/Info.plist Config/USBDisplay.entitlements`: Passed.
- Running-app two-device check on macOS 27: Passed; the connected iPad and iPhone displayed live content in separate windows, and sidebar selection focused the existing device window without duplication.
- Independent window lifecycle check: Passed; closing one device window stopped only that coordinator and left the other window running.
- Running-app layout check: Passed for hidden visual titles, one system sidebar toggle, sidebar containment, 16-point system-background whitespace, and proportional landscape and portrait previews.
- Native full-screen check: Passed with no connection label, quality menu, custom button, or custom top overlay.
- Dynamic physical rotation, hot unplug/replug, occupied-device recovery, camera permission denial, 30-minute concurrent soak, sustained frame rate, and external latency measurement: Not run.

### Remaining Risks or Follow-up Work

- Repeat the two-device concurrent test on other Mac, iPhone, iPad, cable, and macOS combinations because AVFoundation does not guarantee this topology.
- Validate live aspect-ratio changes during physical device rotation and verify that hot-unplugging one device does not affect the other live window.
- Run a 30-minute two-window soak and external latency and frame-rate measurements if performance claims are required.
- Install a valid Apple Development signing identity if stable development signing and hardened Debug runtime are required.
