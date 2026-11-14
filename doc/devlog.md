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

## 2026-09-03 — Switch Devices In Place and Lock Window Proportions

### Summary

- Changed device row left-click behavior to switch the current window instead of opening another window.
- Added an `Open in New Window` context-menu action and preserved one typed window per device; already-open devices are focused rather than duplicated.
- Separated row tap handling from the context menu so a right-click cannot trigger the left-click device switch path.
- Added atomic device ownership transfer so a failed switch to an already-owned device preserves the current window assignment.
- Removed the 16-point white display inset and extended the black detail surface under a transparent full-size title bar while retaining standard window controls and the sidebar toggle.
- Added sidebar-aware proportional window sizing that preserves height on device changes, constrains manual resizing, follows sidebar visibility and width, and fits the current display's visible area.
- Kept native full screen outside the normal-window constraint so the complete source remains aspect-fit with black bars instead of being cropped.
- Replaced the inset preview layout tests with window-sizing and routing coverage.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Models/DeviceWindowRoutingPolicy.swift`
- `USBDisplay/Models/PreviewLayoutPolicy.swift`
- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Services/AppModel.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/DisplayWindowScene.swift`
- `USBDisplay/Views/PreviewView.swift`
- `USBDisplay/Views/SidebarView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/DeviceWindowRoutingTests.swift`
- `USBDisplayTests/PreviewLayoutPolicyTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `xcrun swift-format lint --recursive USBDisplay USBDisplayTests`: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: Passed 26 tests across four suites.
- The first sandboxed Xcode test invocation failed because `swift-plugin-server` could not return Observation macro implementations; the same test command passed when rerun outside the filesystem sandbox.
- `script/build_and_run.sh --verify`: Passed; built and launched the application and confirmed the process.
- `plutil -lint USBDisplay.xcodeproj/project.pbxproj Config/Info.plist Config/USBDisplay.entitlements`: Passed.
- Strict ad-hoc signature verification and built entitlement inspection: Passed.
- Running-app chrome check on macOS 27: Passed; the black detail surface reached the top window edge while standard window controls and the sidebar button remained usable.
- Running-app sidebar check: Passed; collapsing the sidebar produced a continuous full-height black detail surface.
- Running-app context-menu check: Passed; the menu appeared and reopening the current device reused its typed window.
- Live source ratio, two-device left-click switching, opening a second device from the context menu, manual proportional resizing, physical rotation, hot unplug/replug, and full-screen aspect bars: Not run successfully because the current system capture helper remained in Connecting and only one iPad was enumerated.

### Remaining Risks or Follow-up Work

- Reconnect both devices after resetting the macOS capture helper, then validate left-click switching, context-menu multiwindow capture, live manual resizing, physical rotation, and sidebar-width changes.
- Repeat the two-device concurrent test on other Mac, iPhone, iPad, cable, and macOS combinations because AVFoundation does not guarantee this topology.
- Run a 30-minute two-window soak and external latency and frame-rate measurements if performance claims are required.
- Install a valid Apple Development signing identity if stable development signing and hardened Debug runtime are required.

## 2026-09-03 — Restore the Native Title Bar and Auto-Hide Window Buttons

### Summary

- Restored the separate native macOS title bar, system background, and separator so the sidebar and display surface begin below the title bar.
- Kept the logical device title visually hidden and preserved the native sidebar toolbar button.
- Added per-window title-bar tracking and local mouse-move handling for the native close, minimize, and zoom buttons.
- Kept all three standard buttons visible while the sidebar is expanded; when it is collapsed, the buttons appear on title-bar hover and hide 0.5 seconds after the pointer leaves.
- Preserved native full-screen behavior and restored the correct button state after exiting full screen.
- Added a testable window-control visibility state covering sidebar visibility, pointer entry and exit, delayed hiding, cancellation, and sidebar restoration.

### Affected Files

- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `xcrun swift-format lint --recursive USBDisplay USBDisplayTests`: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: Passed 32 tests across four suites.
- The first test build failed because two Swift Testing assertions invoked mutating state methods inside `#expect`; the return values were stored before assertion and the complete test suite then passed twice.
- `script/build_and_run.sh --verify`: Passed; built and launched the application and confirmed the process.
- Running-app title-bar check on macOS 27: Passed; the native title bar and separator were restored and the display surface began below them.
- Running-app window-control check: Passed; collapsing the sidebar hid only the three standard window buttons, title-bar hover restored them, leaving the title bar hid them again, and expanding the sidebar restored them permanently.
- Running-app full-screen round trip: Passed; native full screen hid the title-bar controls and exiting restored the expanded-sidebar state.
- The connected iPhone displayed live content during the initial title-bar check. After later rebuilds, the system capture helper remained in Connecting, so live proportional resizing and rotation were not revalidated in the final build.
- `plutil -lint USBDisplay.xcodeproj/project.pbxproj Config/Info.plist Config/USBDisplay.entitlements`: Passed.
- Strict ad-hoc signature verification and built entitlement inspection: Passed.

### Remaining Risks or Follow-up Work

- Reconnect both devices after resetting the macOS capture helper, then validate live proportional resizing, physical rotation, and independent hover behavior in two simultaneous windows.
- Confirm the 0.5-second hide timing with normal physical pointer movement on additional macOS versions because synthetic UI actions do not provide frame-accurate timing measurements.
- Install a valid Apple Development signing identity if stable development signing and hardened Debug runtime are required.

## 2026-09-03 — Collapse and Reveal the Native Title Bar

### Summary

- Replaced button-only hiding with a three-state window-chrome policy for persistent sidebar chrome, compact screen-only chrome, and temporary hover-revealed chrome.
- Removed the native title-bar material, separator, toolbar, traffic-light buttons, and sidebar button when the sidebar is collapsed.
- Added a full-width 8-point top reveal region and an expanded title-bar tracking region with an 8-point transition bridge.
- Added a 0.5-second delayed collapse with cancellation on pointer re-entry and a 0.15-second native frame animation.
- Measured the actual title-bar decoration height and adjusted the outer window frame so revealing controls does not cover, resize, stretch, or crop the display surface.
- Preserved the compact frame through hover, window movement, resizing, screen-edge fitting, and full-screen transitions.
- Extended the SwiftUI display surface into the compact full-size content region and removed a residual top safe-area strip.
- Added unit coverage for all chrome states, delayed hiding, rapid re-entry, frame compensation, fixed-bottom behavior, screen-top fitting, and invalid decoration heights.

### Affected Files

- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `xcrun swift-format lint --recursive USBDisplay USBDisplayTests`: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: Passed 36 tests across four suites.
- The first sandboxed Xcode verification failed because Swift macro compilation could not apply its nested sandbox; the same build-and-launch verification passed outside the filesystem sandbox.
- `script/build_and_run.sh --verify`: Passed; built and launched the final Debug application and confirmed the process.
- `plutil -lint USBDisplay.xcodeproj/project.pbxproj Config/Info.plist Config/USBDisplay.entitlements`: Passed.
- Strict ad-hoc signature verification and built entitlement inspection: Passed; the camera-device entitlement remains present.
- Running-app compact check on macOS 27: Passed; the collapsed-sidebar window contained only the black display surface with no title-bar material, separator, toolbar button, traffic-light button, or residual top safe-area strip.
- Running-app hover and geometry check: Passed; the same window changed from 981 x 676 points in compact mode to 981 x 728 points with the title bar revealed and returned to 981 x 676 points after the delay. The 52-point height increase left the display size and window width unchanged.
- Running-app native-control check: Passed; the revealed toolbar exposed the system sidebar button and standard window controls.
- Running-app multiwindow check: Passed for independent chrome state in two typed windows.
- Native full-screen round trip: Passed from the expanded-sidebar state.
- Live physical rotation, live proportional resizing, hot unplug/replug, occupied-device recovery, and sustained two-device capture: Not run successfully because the system capture helper did not provide a stable final live stream.

### Remaining Risks or Follow-up Work

- Activate the temporarily revealed sidebar button during another physical-pointer run and confirm that it converts the window directly to persistent sidebar chrome after the final rebuild.
- Reconnect both devices after resetting the macOS capture helper, then validate physical rotation, live proportional resizing, independent two-device capture, and hot unplug behavior.
- Confirm title-bar animation and delayed-hide timing on macOS 14 and 15 because the runtime check used macOS 27.
- Install a valid Apple Development signing identity if stable development signing and hardened Debug runtime are required.

## 2026-09-05 — Add Adaptive Device Corners and Post-Drag Window Snapping

### Summary

- Kept expanded display content below the native title bar and limited top safe-area extension to the fully compact state.
- Replaced the automatically positioned split-view control with one native navigational toolbar item beside the traffic-light controls, using the responder chain and dynamic Show/Hide labels.
- Added public device-model metadata, iPhone/iPad classification, normalized automatic corner profiles, and local per-device custom overrides stored under SHA-256-derived keys.
- Added an `Adjust Screen Corners…` context-menu panel with Automatic and Custom modes, a 0–20% slider in 0.5% steps, live preview, reset, and done controls.
- Applied transparent continuous corner masking only to fully compact windows and restored the native opaque presentation for expanded, hover-revealed, and full-screen states.
- Removed proportional `setFrame` calls from live resizing, allowed temporary aspect-fit bars during the gesture, and added one 0.12-second edge-anchored ratio snap after release.
- Debounced sidebar-width changes for 0.1 seconds and coalesced device, orientation, chrome, and programmatic layout updates.
- Preserved the expanded sidebar across a native full-screen round trip unless it was deliberately changed while full screen.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Models/DisplayCornerProfile.swift`
- `USBDisplay/Models/DisplayDevice.swift`
- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Services/CornerRadiusPreferences.swift`
- `USBDisplay/Services/DeviceCatalog.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/CornerAdjustmentView.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/DisplayWindowScene.swift`
- `USBDisplay/Views/SidebarView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/CornerRadiusPreferencesTests.swift`
- `USBDisplayTests/DisplayCornerProfileTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `xcrun swift-format lint --recursive USBDisplay USBDisplayTests`: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: Passed 48 tests across six suites.
- The initial sandboxed Xcode build could not run the Observation macro plugin; the same build and all final validations passed outside the filesystem sandbox.
- `script/build_and_run.sh --verify`: Passed; built and launched the final Debug application and confirmed the process.
- `plutil -lint USBDisplay.xcodeproj/project.pbxproj Config/Info.plist Config/USBDisplay.entitlements`: Passed.
- Strict ad-hoc signature verification and built entitlement inspection: Passed; the camera-device entitlement remains present.
- Running-app iPhone safe-area check on macOS 27: Passed; the complete status bar and top sensor region remained below the expanded native title bar.
- Running-app sidebar-control check: Passed; the control appeared beside the traffic lights, changed between `Hide Sidebar` and `Show Sidebar`, and expanded the sidebar from temporary hover chrome.
- Running-app corner check: Passed; compact mode used the rounded transparent device presentation, while hover-revealed, expanded, and full-screen modes used the native Mac presentation.
- Running-app corner-adjustment check: Passed; Automatic and Custom switched correctly, 10.0% was accepted, Reset restored the 14.0% automatic iPhone profile, and Done dismissed the panel.
- Running-app expanded resize check: Passed; a bottom-right live drag grew the window from 311 x 372 to 452 x 680 points and the settled detail area returned to the exact live portrait ratio without permanent bars, cropping, or stretching.
- Native full-screen round trip: Passed; full screen used aspect-fit black bars without custom masking and exit restored the expanded sidebar and native title bar.
- iPad compact corners, physical rotation, and live resizing: Not run because no iPad was available for the final build.

### Remaining Risks or Follow-up Work

- Repeat the physical resize check for every individual edge and corner and with rapid repeated gestures; all eight edge-anchor cases are covered by unit tests, but only an expanded bottom-right live drag was checked in the running app.
- Repeat compact-corner, rotation, and resize validation with a connected iPad.
- Confirm native-toolbar placement and title-bar transitions on macOS 14 and 15 because the running-app checks used macOS 27.
- Run hot unplug/replug, occupied-device recovery, camera-permission denial, a 30-minute capture soak, and external latency and sustained-frame-rate measurements.
- Install a valid Apple Development signing identity if stable development signing and hardened Debug runtime are required.

## 2026-09-05 — Stabilize Window Geometry and Match Device Corner References

### Summary

- Added per-window in-memory preferred preview geometry. Sidebar and hover chrome now derive their frames from that preference, adding space to the left and above, fitting to the display without overwriting the preferred size, and preserving ordinary-window state across full-screen transitions.
- Replaced competing AppKit animations and post-release snapping with one cancellable frame timer and a forwarding resize delegate. Live resize proposals subtract fixed sidebar and title-bar contributions before applying the source ratio; ordinary release commits the user geometry without setting another frame. Hover changes are suspended during resizing.
- Preserved SwiftUI window ownership and original delegate forwarding, and restored the original delegate when detaching.
- Connected actual compact presentation back to the SwiftUI detail safe area. Physical validation exposed and fixed a 32-point blank top inset that plain AppKit policy tests did not reveal.
- Replaced guessed iPhone/iPad percentages with exact model-ID matching against 80 checked-in Apple Simulator display-reference profiles. Recorded calibration units and source hashes, exposed matched/manual/unmatched status, retained existing hashed custom overrides, and made unknown models use zero custom radius until manually calibrated.
- Replaced obsolete post-drag/centered-frame tests with preferred-geometry and AppKit integration coverage. Added narrow resize and public-model diagnostics without logging unique device identifiers or captured content.

### Affected Files

- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Models/DisplayCornerProfile.swift`
- `USBDisplay/Services/CornerRadiusPreferences.swift`
- `USBDisplay/Services/DeviceCatalog.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/CornerAdjustmentView.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/DisplayCornerProfileTests.swift`
- `USBDisplayTests/CornerRadiusPreferencesTests.swift`
- `doc/device-corner-profiles.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Swift format lint and whitespace checks: Passed.
- Xcode Debug and Release builds: Passed.
- Xcode unit and AppKit integration tests: Passed 54 tests across eight suites.
- `script/build_and_run.sh --verify`: Passed; the application built, launched, and was detected as running.
- The sandboxed compiler initially could not run the Observation macro plugin; builds and tests ran successfully outside that sandbox. An initial integration-test crash came from a temporary test window's release-on-close setting; disabling release-on-close and serializing those window tests resolved it.
- Physical connected-iPhone sidebar check: Passed 20 consecutive expanded/compact round trips. Every expanded frame was 406 x 579 points and every compact frame was 243 x 527 points, without cumulative size drift.
- Physical compact safe-area check: Passed after the detail-view correction. Debugger inspection had confirmed the old compact frame was 579 points high while its preview occupied only 547 points; the corrected preview filled the compact surface.
- Physical expanded and compact full-screen round trips: Passed; both restored their previous dimensions and sidebar visibility, and full screen retained the complete aspect-fit picture.
- Physical corner panel: Passed; the connected capture model was unmatched, Custom accepted 10.0%, and Reset restored unmatched Automatic at 0.0%. The test left the original automatic preference in place.
- Physical pointer resizing: Attempted but not validated. Computer Use produced resize begin/end events without intermediate resize proposals or a frame change, so it cannot establish drag responsiveness or handle anchoring. Real NSWindow integration tests exercised width, height, diagonal proposals, interruption, and release stability separately.
- Physical iPad, a live matched model profile, device rotation, and monitor-edge fitting: Not run; those hardware scenarios remain outstanding.

### Remaining Risks or Follow-up Work

- Manually verify all eight resize handles, rapid successive drags, and hover/resize interleaving on a physical pointer. Do not equate the integration-test proposals with an end-to-end gesture check.
- Verify screen-edge fitting, sidebar-divider dragging, physical rotation, and multiple connected devices. No iPad was available for the final live checks.
- Exact public capture model IDs may be generic or absent from the table. Such devices require manual calibration; simulator reference radii are not live physical hardware measurements. Validate the appearance of matched profiles on corresponding hardware.
- Recheck native toolbar and safe-area behavior on macOS 14 and 15; live validation used macOS 27.
- Existing hot-unplug/replug, occupied-device, permission-denial, capture-soak, signing, and external latency checks remain outstanding.

## 2026-09-05 — Keep Preview Geometry Stable and Identify USB Corner Profiles

### Summary

- Moved the persistent preview out of `NavigationSplitView` into an app-owned AppKit container with explicit preview, sidebar, status, divider, and titlebar frames. SwiftUI still owns window lifecycle, selection, and multi-window routing.
- Removed the outer-frame timer, competing deferred geometry adjustments, preview safe-area switching, and SwiftUI-root corner mask. Chrome commits its complete target geometry synchronously; video stays attached to the same preview layer.
- Added outside-versus-overlay chrome layout. Sidebar expansion uses space on the left and titlebar expansion uses space above; screen-edge fitting translates without shrinking. Controls overlay along an axis when the combined dimensions cannot fit, and closing them restores preferred geometry.
- Kept proportional AppKit resize proposals and delegate forwarding, suspended hover during resizing, and moved shadow invalidation to operation completion. Preview bounds and the app-owned continuous mask update in one nonanimated Core Animation transaction.
- Kept windows and containers transparent, with black confined to the preview. Full-screen validation exposed an empty titlebar strip; full screen now uses the entire display height while native toolbar reveal remains system-managed.
- Added an asynchronous, read-only usbmuxd/lockdownd client for `ProductType` and `DeviceName`, with a four-second total deadline, bounded framing, fragmented I/O support, cancellation checks, and stale-generation rejection.
- Associated capture and USB records only by names unique on both sides of a complete snapshot. Generic capture models, aspect ratios, ambiguous names, and enumeration order cannot select a model profile.
- Applied exact USB product profiles automatically and exposed identification status in the device list. Removed the manual adjustment UI and preference reader/writer without deleting any stored legacy overrides.
- Updated the current state and profile documentation, and added protocol/compatibility documentation. Added protocol, geometry, multi-window, full-screen, and composed-rendering coverage.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Models/DisplayDevice.swift`
- `USBDisplay/Models/DisplayCornerProfile.swift`
- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Services/AppModel.swift`
- `USBDisplay/Services/DeviceCatalog.swift`
- `USBDisplay/Services/USBDeviceInfoService.swift`
- `USBDisplay/Services/CornerRadiusPreferences.swift` (removed)
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/DisplayWindowScene.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/PreviewView.swift`
- `USBDisplay/Views/SidebarView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplay/Views/CornerAdjustmentView.swift` (removed)
- `USBDisplayTests/DisplayCornerProfileTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/USBDeviceInfoTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `USBDisplayTests/CornerRadiusPreferencesTests.swift` (removed)
- `doc/current.md`
- `doc/device-corner-profiles.md`
- `doc/usb-device-identification.md`
- `doc/devlog.md`

### Validation

- Strict Swift-format lint, working-tree whitespace checks, Debug and Release builds, and strict Debug/Release bundle signature verification: Passed.
- Full Xcode regression run after the full-screen correction: Passed 62 tests, zero failures and zero skips. The subsequently strengthened rendering test was rerun successfully against the same application implementation.
- AppKit geometry tests: Passed checks of every applied preview rectangle through 20 sidebar/titlebar cycles, constant layer identity, translation/overlay without scaling, orientation height restoration, independent windows, 160 intermediate resize proposals across compact/expanded states and eight direction vectors, drag takeover, hover suppression, full-screen restoration, and delegate forwarding. These programmatic proposals are not physical pointer acceptance.
- Rendering checks: Passed 12 changing red/blue synthetic presentations in compact, sidebar-expanded, and hover-titlebar states, with center/right/bottom pixel checks after resizing. The complete SwiftUI hosting surface and native frame hierarchy retained transparent compact corners over black and white backgrounds. An initial test-harness failure compared semantic colors across color spaces and used copy instead of source-over composition; explicit primary-color checks and source-over compositing corrected the measurement. This is AppKit bitmap validation, not a WindowServer frame-pacing recording of captured video.
- USB checks: Passed model-response/profile fixtures for `iPhone17,1`, `iPhone18,1`, and `iPhone18,2`; duplicate capture/USB names; unknown products; legacy-data preservation; invalid, oversized, and fragmented responses; local-socket timeout, cancellation and disconnect; and late-result rejection after device replacement. Only allowed GetValue keys were sent by the socket fixture.
- Physical iPhone identification: Passed. The capture model remains `iOS Device`; the running app identifies the USB product as iPhone 16 Pro and displays `Automatic corners`. The normalized profile is 62 / 402. The final app resumed live capture after a camera-permission wait following ad-hoc rebuilding.
- Physical sidebar/titlebar interaction: Completed 22 recorded round trips, yielding 20 valid endpoint size pairs of 221 x 479 compact and 442 x 531 expanded. Two screenshots returned unexpected small image dimensions (127 x 151 and 143 x 171) and were not counted. A separate ScreenCaptureKit capture error and a stale click-position error interrupted automation. Therefore this is not claimed as 20 uninterrupted, frame-by-frame validated physical cycles. Live phone content continued updating in observed snapshots.
- Physical full screen: Expanded exit restored 442 x 531 during the earlier live pass. The final corrected build was visually checked in full screen: the white titlebar strip was absent, the complete picture remained visible with side bars, and exit restored the final window's 308 x 668 compact size and hidden sidebar. Sizes from different application lifetimes are not compared as a persistence guarantee.
- Physical resize attempts on the final build: Tried all eight edges/corners. Every attempt left the 529 x 720 outer size unchanged, and each logged live-resize begin/end with zero constrained proposals. Actual continuous dragging, release anchoring, fast repeated drags, and hover/resize interleaving are not validated by these events.
- Canonical `./script/build_and_run.sh --verify`: Passed. The final Debug application remains running with the connected iPhone. No phone screenshots or identifying capture/USB serial values were added to the repository.

### Remaining Risks or Follow-up Work

- Perform a physical-pointer acceptance pass for all eight resize handles, rapid successive drags, and hover/resize interleaving; the automation did not generate usable intermediate drag events.
- Record actual WindowServer-composited video frame by frame over contrasting desktop backgrounds to check physical playback continuity and any one-frame white/black flash. JPEG-only UI snapshots and AppKit bitmap tests cannot establish that result.
- Repeat 20 uninterrupted physical sidebar cycles and live monitor-edge translation/overlay checks. Physical monitor-edge dragging was not run; edge behavior is covered by deterministic geometry tests.
- Physical iPhone 17 Pro, iPhone 17 Pro Max, iPad, rotation, hot unplug/replug, and concurrent multi-device capture: Not run. Do not treat protocol/reference fixtures as hardware passes.
- Maintain compatibility with usbmuxd/lockdownd protocol changes and validate native toolbar behavior on macOS 14/15. Unavailable or ambiguous identities deliberately use zero custom radius.
- Existing occupied-device recovery, permission-denial, capture-soak, production-signing, distribution, and external latency/frame-rate checks remain outstanding.

### Final Review Follow-up

- Corrected ordinary-window restoration when the source rotates during full screen. Exit now applies the current source ratio to the retained preferred height before committing the restored frame.
- Extended the full-screen integration test with a rotation during full screen. The final full regression run, including the strengthened rendering test, passed all 62 tests with zero failures or skips. Physical rotation remains Not run.

## 2026-09-05 — Suppress Compact Window Shadows and Check Outermost Edges

### Summary

- Disable the native window shadow when the controls are fully collapsed, preserving the existing rounded preview mask and opaque video content. Restore the original shadow setting when controls return or the host detaches.
- Preserve the native window style, SwiftUI scene ownership, preview layer, resize behavior, and macOS 14 deployment target.
- Extend rendering coverage to the outermost pixel on all four straight edges. Compare each sampled pixel with the rendered center in the same color space so a one-pixel rim cannot pass an inset-only check.
- Add a real SwiftUI scene regression check for compact key/main-window eligibility and the native close/full-screen buttons after titlebar reveal.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Strict recursive Swift-format lint and working-tree whitespace checks: Passed.
- Debug and Release builds: Passed. Full regression suite: 63 tests passed, zero failures and zero skips.
- Synthetic AppKit rendering: Passed changing red/blue frames, corner alpha over light/dark backgrounds, all four outermost edge pixels, and compact/expanded shadow state. These are bitmap checks, not WindowServer screenshots.
- Actual SwiftUI scene ownership: Passed compact key/main-window eligibility and restored native buttons.
- Canonical `./script/build_and_run.sh --verify`: Passed; the final Debug process launched. Strict Debug/Release bundle signature verification after the canonical build completed: Passed.
- An initial sandboxed build could not launch Swift macro plugins; the authorized build outside the sandbox succeeded. Experimental removal of the titled window style, including a plain-scene variant, failed actual SwiftUI focus/button tests and was fully reverted. A color assertion was corrected to compare pixels within the same rendered color space.
- Physical appearance, right-edge white-line removal, and live playback inspection: Not run. Computer-use inspection reported that the Mac was locked and automatic unlock failed. The user was asked to unlock it.

### Remaining Risks or Follow-up Work

- Inspect the compact running window after unlock against both light and dark backgrounds. Confirm that the reported white line and rectangular outline are gone; shadow suppression alone is not yet claimed to resolve every visible WindowServer artifact.
- Complete the existing physical drag, hover, full-screen, and video-continuity acceptance checks. No physical acceptance result from the previous entry is extended to this change.

## 2026-09-05 — Expand the Automatic Device Corner Catalog

### Summary

- Replace the 80-entry Swift table with a validated bundled JSON catalog of 164 product identifiers: 60 iPhone and 104 iPad. Retain every previous identifier and add 84 corroborated hardware variants and older devices. Runtime selection still requires the exact USB ProductType and never downloads metadata.
- Preserve 85 Apple Simulator source-bundle observations, including their original plist hashes. Pin complete BezelKit and DeviceKit metadata snapshots and MIT licenses to immutable upstream revisions and SHA-256 hashes.
- Generate variant mappings from explicit DeviceKit hardware groups. Use an exact Apple member for rounded-display geometry; accept older square displays only when DeviceKit and BezelKit agree on zero. Parse downloaded GYB literals without executing the source.
- Review five source conflicts. Correct the iPad Air 3 profile to zero, retain the existing Apple references for iPhone 12 / 12 Pro / 12 Pro Max, and correct BezelKit's iPad16,8 name/radius using the explicit iPad Air M4 group. Exclude six uncorroborated upstream identifiers rather than guessing.
- Add an offline generator, pinned-download refresh command, generated source audit, and bundled third-party notices. Unreviewed numeric conflicts, stale decisions, changed parser schemas, source-hash mismatches, and invalid geometry stop generation. Keep upstream source files unchanged for reproducible hash verification.

### Affected Files

- `.gitignore` (ignore Python bytecode caches)
- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay/Models/DisplayCornerProfile.swift`
- `USBDisplay/Resources/device-corner-profiles.json`
- `USBDisplay/Resources/ThirdPartyNotices.txt`
- `USBDisplayTests/DisplayCornerProfileTests.swift`
- `data/device-profiles/apple-simulator.json`
- `data/device-profiles/bezelkit.json`
- `data/device-profiles/devicekit.gyb`
- `data/device-profiles/bezelkit-LICENSE.txt`
- `data/device-profiles/devicekit-LICENSE.txt`
- `data/device-profiles/upstream-lock.json`
- `data/device-profiles/decisions.json`
- `script/update_device_profiles.py`
- `script/test_device_profiles.py`
- `doc/device-corner-catalog.md`
- `doc/device-corner-profiles.md`
- `doc/usb-device-identification.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Full Debug Xcode suite: Passed 67 tests, zero failures and zero skips. New checks cover bundled coverage, corroborated aliases, reviewed conflicts, old square displays, unknown identifiers, normalization in both orientations, and invalid resource schemas, duplicates, and geometry. Existing protocol, rendering, window lifecycle, and geometry regressions also passed.
- Python generator suite: Passed nine tests covering reproducibility, preserved Apple coverage, new/stale conflict rejection (including Apple-only fallback records), conflicting memory variants, missing measured geometry, nonfinite values, duplicate/schema changes, and nonexecution of downloaded source.
- Independently compared the previous Swift table with generated output: all 80 identifiers retained; the only changed existing radius/short-side pair is the reviewed iPad Air 3 correction.
- Offline generation and `--check`: Passed. The actual `--download` command re-fetched both pinned public sources and licenses with matching hashes; subsequent generation remained reproducible.
- Strict recursive Swift-format lint, project plist validation, working-tree and staged whitespace checks: Passed. Debug and Release builds: Passed. Both app bundles contain catalog and notice resources byte-identical to the generated files. Strict Debug/Release signature verification: Passed.
- Canonical `./script/build_and_run.sh --verify`: Passed. The running application showed the connected device as iPhone 16 Pro with `Automatic corners`, confirming the expanded catalog still resolves the current physical device.
- Live video appearance, continuous playback, and the reported edge artifacts: Not run to acceptance. The Mac was unlocked for this check, but the preview was black in both expanded and compact snapshots. Identification success is not a playback or corner-compositing pass. No device screenshots or identifying serial values were committed.

### Remaining Risks or Follow-up Work

- Validate reference geometry on additional physical iPhone/iPad models. The 164 identifiers represent metadata coverage; unavailable devices and older-device capture compatibility were not tested physically.
- Review future upstream conflicts against traceable evidence. Six excluded BezelKit identifiers remain explicitly listed in the generated audit; new rounded groups need an Apple geometry anchor before inclusion.
- Restore or investigate visible live capture, then complete the previously outstanding white-line/rectangular-outline, frame-continuity, pointer-drag, hover, screen-edge, full-screen, and multiple-device acceptance checks. This data-catalog change does not claim to resolve those appearance or playback checks.

## 2026-09-05 — Cover Rounded Window Frames Without Edge Gaps

### Summary

- Rebase every chrome commit on the actual NSWindow frame after AppKit accepts it. A live diagnostic found a 237.336384-point preview request inside a 238-point window; retaining the request left an uncovered right strip, including when only the titlebar was visible.
- Keep ordinary, source-proportional video in aspect-fill mode so frame quantization does not introduce thin black letterboxing. This can crop the small rounding remainder at the opposite edges; it does not stretch the image. Full screen, full-screen transitions, and unknown source geometry continue to show the complete aspect-fit image.
- Synchronize preview bounds, continuous-corner radius, and backing scale immediately on frame/bounds changes. Disable implicit actions and avoid reassigning unchanged geometry/gravity. Retain the preview instance, capture session, native window style, toolbar behavior, and existing model catalog.
- Extend rendered-edge coverage to every chrome state using fractional iPhone geometry. Add immediate-commit and deferred-layout regression checks rather than relying only on a later forced layout.

### Affected Files

- `USBDisplay/Views/PreviewView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Before the fix, the new immediate-commit test failed with a requested width of 237.33638443935928 versus an accepted window width of 238. The previous bitmap test still passed after a forced layout, confirming why it had missed this gap. Temporary geometry diagnostics were removed from the final implementation.
- Final full Debug regression suite: Passed 69 tests, zero failures and zero skips. New checks cover 20 sidebar/titlebar cycles with 80 immediately observed commits, 40 direct preview resizes plus a bounds change before deferred layout, synchronized video/mask geometry without implicit animations, and ordinary/full-screen gravity selection. Existing window, routing, capture, identity, and catalog regressions passed.
- Dynamic AppKit rendering: Passed fractional iPhone aspect-ratio proposals in compact, sidebar-expanded, and titlebar-only states, including all four outermost straight-edge pixels and corner transparency over light/dark backgrounds. These are synthetic bitmap checks, not physical pointer or WindowServer frame-pacing checks.
- Debug and Release builds, strict recursive Swift-format lint, whitespace checks, and strict Debug/Release signature verification: Passed. Canonical `./script/build_and_run.sh --verify`: Passed. An initial CGFloat/Double compile mismatch was corrected; one exact floating-point radius assertion was changed to a subpixel tolerance after a roughly 4e-15 difference.
- Running iPhone 16 Pro: The pre-fix titlebar-only white line was observed. After rebuilding, native Zoom recovered visible video from an initially narrow black preview. Expanded and compact live snapshots reached the straight edges without the prior uncovered strip, and a further native Zoom size change retained border-free compact edges. These observations are endpoint checks, not a continuous drag pass.
- Pointer/hover automation: Not run to acceptance. Compact edge-drag and subsequent coordinate-hover attempts repeatedly returned computer-use error `-10005: noWindowsAvailable`; no usable resize proposals were recorded. The process remained alive, and accessibility menus and screenshots continued working. Reacquiring the app, raising/centering the window, and resetting the automation session did not restore coordinate operations. The final titlebar-only physical check therefore remains incomplete despite passing synthetic coverage.
- No device screenshots, personal phone content, or temporary diagnostics were added to the repository.

### Remaining Risks or Follow-up Work

- Perform physical continuous drags from all eight edges/corners in compact mode, including quick reversals, and verify no black strips during or after resizing. Native Zoom and delegate proposals are not substitutes for this check.
- Recheck the final build with only the hovered titlebar visible and the sidebar closed, against light and dark backgrounds. Record actual WindowServer frames if any white line or flash remains.
- Investigate the initially narrow restored window and delayed/black preview observed after relaunch. Native Zoom recovered playback during this run; startup behavior was not changed or claimed fixed.
- Existing multi-device, rotation, monitor-edge, full-screen hardware, older macOS, and performance acceptance work remains as recorded in the current project state.

## 2026-09-05 — Show Only Device Models in the Sidebar

### Summary

- Replace the device-name/status stack with a single model label, such as `iPhone 16 Pro`.
- Remove automatic-corner, missing-profile, and identification-status annotations and their tooltip. Fall back to ProductType, then the capture name, when a model name is unavailable.
- Preserve automatic corner selection, identity matching, capture routing, and device identifiers.

### Affected Files

- `USBDisplay/Models/DisplayDevice.swift`
- `USBDisplay/Views/SidebarView.swift`
- `doc/current.md`
- `doc/usb-device-identification.md`
- `doc/devlog.md`

### Validation

- Canonical `./script/build_and_run.sh --verify`: Passed; Debug build and process launch succeeded.
- Strict recursive Swift-format lint and working-tree/staged whitespace checks: Passed. Source inspection confirms the old status strings and tooltip are no longer part of the device row.
- Release build and unit tests: Not run for this display-text-only change. No new tests were added.
- Running-window visual/accessibility verification: Not run. Computer use reported that the Mac was locked and automatic unlock failed.

### Remaining Risks or Follow-up Work

- Confirm the single model label in the unlocked application. Existing window/capture acceptance items remain unchanged.


## 2026-09-05 — Balance Empty Windows at a 30/70 Split

### Summary

- Give placeholders without an active source ratio approximately 30% of the window width for the sidebar and 70% for the content, including the divider in the sidebar allocation. Keep the split responsive during freeform empty-window resizing.
- Apply a nominal 720-by-480-point minimum that fits the available screen, and repair late narrow window restoration synchronously. Native toolbar constraints can increase the effective minimum height. An explicitly hidden sidebar leaves the whole width to content.
- Keep each window's empty frame separate from its preferred video geometry. Restore proportional video sizing and its existing minimum once a connected source ratio is available; restore the empty layout on disconnect. Ignore a stopped capture's retained ratio at the SwiftUI configuration boundary.
- Freeze the active layout mode during live resizing and apply newly available source geometry after release. Initialize ordinary video geometry correctly when the device arrives during a full-screen transition.

### Affected Files

- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Full Debug regression suite: Passed 75 tests, zero failures and zero skips. Six added tests cover responsive placeholder widths, small/offset screens, narrow initial and late-restored frames, freeform resize proposals, separate empty/video sizes and windows, connection during a drag, full-screen restoration/device arrival, and real SwiftUI content with a stale capture ratio. Existing proportional-resize, chrome-stability, corner-rendering, identity, and capture tests passed.
- Debug and Release builds, strict recursive Swift-format lint, working-tree/staged whitespace checks, and strict Debug/Release bundle signature verification: Passed. Canonical `./script/build_and_run.sh --verify`: Passed.
- During validation, an optional CGFloat-to-Double conversion was corrected. An exact minimum-height test was updated to allow AppKit's extra native toolbar height; width remains constrained and the effective height stays at least the configured minimum.
- Running application: Opened a new unselected window through `File > New USB Display Window`. The screenshot showed 294 of 980 points allocated to the sidebar and 686 to content. Native Zoom retained the approximate 30/70 split; Zoom restored the initial size. The connected device row showed only `iPhone 16 Pro`. No phone screenshots or temporary diagnostics were added to the repository.
- Physical unplug/no-device startup and continuous pointer drags: Not run. The empty SwiftUI fixture has no devices or active capture, but is not a physical unplug test. The running-app check used an unselected window while the iPhone remained connected. Python catalog-generator tests were not rerun because the catalog and generator were unchanged.

### Remaining Risks or Follow-up Work

- Recheck physical unplug/reconnect and first-frame video timing. The earlier black preview at startup is not claimed fixed by the placeholder layout.
- Existing continuous-pointer, WindowServer frame pacing, multi-device, monitor-edge, hardware full-screen/rotation, and older-macOS acceptance items remain as recorded in the current state.


## 2026-09-05 — Show Device Names with Model Subtitles

### Summary

- Restore the device name as the sidebar row's primary label and place its resolved model below it in smaller secondary text.
- Omit the subtitle when the model fallback duplicates the device name. Keep identification and corner-status annotations hidden, and preserve row selection and the existing context-menu action.

### Affected Files

- `USBDisplay/Views/SidebarView.swift`
- `doc/current.md`
- `doc/usb-device-identification.md`
- `doc/devlog.md`

### Validation

- Canonical `./script/build_and_run.sh --verify`: Passed; Debug build and process launch succeeded.
- Strict recursive Swift-format lint and working-tree/staged whitespace checks: Passed.
- Running application: the accessibility tree showed the device name followed by `iPhone 16 Pro`. The screenshot confirmed the name as the primary line and the model as smaller secondary text, with no corner-status annotation.
- Release build and unit tests: Not run for this presentation-only change. No tests were added; the preceding full regression run passed 75 Swift tests.

### Remaining Risks or Follow-up Work

- None specific to this row presentation change. Existing capture and window acceptance items remain unchanged.


## 2026-09-05 — Clip Compact Previews with Explicit Alpha Masks

### Summary

- Respond to the supplied compact-window image showing rectangular fragments and isolated pixels outside the rounded video outline.
- Replace implicit layer corner clipping with a persistent `CAShapeLayer` alpha mask covering the complete preview, including video and black backing. Build its path from SwiftUI's continuous rounded rectangle using the existing model-derived radius. The preview layer, session, device profiles, and proportional window geometry remain unchanged.
- Update mask bounds, path, and backing scale in the same nonanimated transaction as the preview. Reuse the mask across resizes and regenerate its path only for size/radius changes. Remove it for zero-radius, expanded, and full-screen presentation. Give the status overlay its own matching mask.
- Expand corner checks beyond the former extreme-corner sample to the entire two-pixel outer strip through 75% of the reference radius at every corner.
- API reference: Apple's [CALayer mask documentation](https://developer.apple.com/documentation/quartzcore/calayer/mask) specifies alpha clipping of both layer content and background and requires the mask's size and position to align with its target.

### Affected Files

- `USBDisplay/Views/PreviewView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Baseline expanded corner-strip check: Passed all 5 rendering-suite tests with the old implicit mask. The user's supplied image is evidence of the live artifact; the bitmap test did not reproduce it. No underlying WindowServer or hardware-driver cause is claimed proven.
- Final full Debug suite: Passed 75 tests, zero failures and zero skips. Updated tests verify the explicit mask persists across 40 preview resizes, follows a direct bounds change without implicit animations, and is removed outside compact mode. Dynamic composed-window checks passed all four outer corner strips and straight edges; existing chrome, source-ratio, empty-state, identity, and capture coverage passed.
- Debug and Release builds, canonical `./script/build_and_run.sh --verify`, strict recursive Swift-format lint, working-tree/staged whitespace checks, and strict Debug/Release signature verification: Passed. Python catalog-generator tests were not rerun because the catalog and generator were unchanged.
- Connected iPhone: Live colored home-screen snapshots showed clean rounded boundaries in compact mode. A computer-use bottom-right drag enlarged the window from approximately 211-by-458 to 271-by-590 image pixels. Further live activity logged two drags with 47 and 28 constrained proposals; a later approximately 233-by-508 snapshot showed clean corners after shrinking. Video content changed between observations, and the preview was not replaced with a still image.
- Further scripted drags were rejected while computer use reported concurrent user changes. The recorded additional drags are live-session observations, not claimed as successful scripted gestures. Native Zoom did not establish a distinct size change in this run and is not counted as resize evidence.
- Continuous WindowServer recording and exhaustive eight-handle/hover-interleaving acceptance: Not run. JPEG snapshots establish visible endpoint appearance, while alpha assertions come from the composed AppKit bitmap checks. No phone screenshots or temporary telemetry files were committed.

### Remaining Risks or Follow-up Work

- Complete all-eight-handle, rapid-reversal, hover/resize, and frame-by-frame WindowServer validation. Recheck the exact original artifact if it recurs; the baseline bitmap test cannot isolate its cause.
- Existing multi-device, older-macOS, physical full-screen/rotation, and first-frame capture timing acceptance items remain as recorded in the current state.


## 2026-09-05 — Stabilize Live Resizing and Animate Window Controls

### Summary

- Replace per-event width/height arbitration with a per-window resize session. A read-only reproduction of the old solver returned widths 301, 300, 303, 300 for monotonically increasing proposals 301, 302, 303, 304. The new solver selects one strategy per gesture, uses raw proposals, freezes actual control insets and screen limits, and leaves origin/anchor handling to AppKit.
- Keep width-driven edges, height-driven edges, and proportional corner projection in one constraint path, with shared minimum/maximum handling and no post-release size correction. Preserve user video geometry when a completed control fade releases reserved space after a drag.
- Introduce a 200-millisecond display-linked control timeline with 8-point travel and fading. Retarget from the current presentation, retain space until closing completes, remove travel under Reduce Motion, and preserve the 30/70 empty-state endpoint. Full-screen native chrome remains system-managed.
- Keep the same capture session, preview view, video layer, and explicit continuous masks. Update controls and masks without implicit animations or per-frame outer-window resizing. Coalesce explicit preview frame/bounds updates, preserve mask path topology at transition endpoints, and keep the black backing inside the same clip.
- Freeze source-ratio publication during geometry changes and require two consistent samples before accepting a subsequent ratio change. Keep the first usable sample immediate. Replace the toolbar item's implicit content with an app-owned native button, preserving navigation placement and accessibility labels.

### Affected Files

- `USBDisplay/Models/ResizeSession.swift`
- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Views/WindowChromeAnimator.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplay/Views/PreviewView.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `USBDisplay.xcodeproj/project.pbxproj`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Final full Debug regression suite: Passed 89 Swift tests, zero failures and zero skips. Fourteen added tests cover raw monotonic proposals; eight handle strategies; diagonal projection, noise and clamp reversal; ratio confirmation; every sampled stage of 20 animated open/close cycles; rapid reversal and metadata updates; drag takeover; hover timelines; separate windows; empty proportions; deferred disconnect/rotation; full-screen cleanup; and edge overlay without video shrinkage.
- Rendered transition checks: Passed current red/blue center and edge colors, stable video-layer identity and screen-space preview rectangle, and all four transparent corner samples at intermediate progress, including light/dark composition. Existing full corner-strip and fractional-window rendering regressions passed. Model-time sampling is separate from live WindowServer frame capture.
- Debug and Release builds, canonical `./script/build_and_run.sh --verify`, strict recursive Swift-format lint, working-tree whitespace checks, and strict Debug/Release bundle signature verification: Passed. The usual App Intents metadata warning reports that this target does not link AppIntents.framework.
- During development, corrected duplicate new Xcode file-reference IDs and Swift Testing assertions involving mutating methods/mixed numeric types. Updated the old exact-window-ratio assertion to distinguish exact delegate results from one-backing-pixel AppKit rounding. A reversal test initially depended on a 60-millisecond task wake-up and failed when scheduling passed the animation deadline; the final test uses the animator's injected clock. The final full suite passed after those corrections.
- Connected iPhone: the relaunched app identified iPhone 16 Pro and displayed live content with clean compact rounded boundaries in observed snapshots. Diagnostics recorded a real resize from 09:03:11.217 to 09:03:15.459 with 341 constrained proposals. This was observed session activity, not a successfully automated gesture or frame-by-frame proof of smoothness.
- Native View-menu full-screen entry/exit: Completed. The complete portrait picture appeared with necessary side bars; exit restored compact rounded presentation at approximately its previous size. No phone screenshots or temporary diagnostics were added to the repository.
- Computer-use right-edge drag attempts: Not completed. One attempt required refreshing a changed application instance/state; two further attempts returned `windowNotFoundAtPosition`, including after raising the window. A transient toolbar item after full-screen exit expired before a click, so that attempt is not counted as sidebar validation. The available tool provides no hover-only gesture or continuous window recording.
- Physical all-eight-handle dragging, rapid reversal and hover interleaving, 20 sidebar round trips, rotation, unplug/replug, multiple physical devices, screen-edge overlay, Reduce Motion, and continuous WindowServer frame pacing: Not run to completion. Unconnected iPhone 17 models/iPads are not claimed as hardware passes. The nine Python generator tests were not rerun because catalog data/generation were unchanged; the Swift catalog regression passed.

### Remaining Risks or Follow-up Work

- Complete physical all-handle anchoring and smoothness acceptance, sidebar/hover interleaving, and continuous video capture over contrasting backgrounds. Endpoint screenshots and proportional delegate tests cannot rule out a transient compositor or driver artifact.
- Recheck real rotation, reconnect, monitor changes/edge overlays, multiple devices, Reduce Motion, and macOS 14/15 native toolbar behavior. Existing capture first-frame timing, distribution/signing, and external latency measurements remain separate acceptance items.


## 2026-09-05 — Reserve Native Window Button Space Before Toolbar Reveal

### Summary

- Fix the supplied screenshot's Show Sidebar button overlapping the native traffic lights after compact mode reveals its titlebar.
- Restore native button visibility and measurement opacity before making the toolbar visible. AppKit then includes the native control area when placing the navigational item. Restore the animation's current opacity inside the same nonanimated transaction, preserving the existing fade and slide without a hard-coded horizontal offset.
- Add a regression fixture using the real scene's unified toolbar style, checking separation from all three native window buttons and the current fade at intermediate animation samples across five sidebar/titlebar cycles.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Baseline focused regression: Failed as expected with ten overlap/spacing assertions. The narrow revealed toolbar placed the toggle at x=26 points while the native buttons occupied x=19...79. Merely changing visibility order still failed; restoring measurement opacity before toolbar reveal placed the toggle at x=96 and passed the focused regression.
- Final full Debug suite: Passed 90 tests, zero failures and zero skips. The expanded regression also checks native-button opacity against the animation progress at 0%, 25%, 50%, 75%, and 100%. Existing resize, alpha-mask rendering, and device tests passed.
- Debug and Release builds, canonical `./script/build_and_run.sh --verify`, strict recursive Swift-format lint, and working-tree whitespace checks: Passed.
- Running application with the connected iPhone 16 Pro in landscape: Revealed the titlebar from the top region, clicked Show Sidebar, clicked Hide Sidebar, and revealed the titlebar again. Screenshots showed the toggle to the right of the native window-control area on both reveals and while expanded. Live video continued changing. No phone screenshots were added to the repository.
- Physical portrait-mode repetition and older macOS versions: Not run in this check. The native unified-toolbar fixture covers narrow portrait geometry. Continuous WindowServer frame pacing and all-handle drag acceptance were not rerun for this focused positioning fix.

### Remaining Risks or Follow-up Work

- Verify macOS 14/15 native toolbar behavior when hardware is available. Previously documented continuous-resize and frame-pacing acceptance items remain outstanding.

## 2026-09-05 — Hide the Full-Screen Toolbar

### Summary

- Show the native toolbar and traffic lights only when ordinary-window titlebar space is reserved. Full screen no longer forces the toolbar visible.
- Preserve the existing ordinary-window control animation and full-screen geometry restoration.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Canonical Debug build and launch (`./script/build_and_run.sh --verify`): Passed after running outside the execution sandbox, which initially prevented Swift macro execution.
- Connected iPhone runtime screenshot: Full-screen video and black backing reach the top edge; the white toolbar and native window buttons are absent. The existing visible sidebar remains visible.
- Initial test filters used a folder name instead of the target/suite names; these attempts are not counted as regression coverage.

- Full Debug regression suite: 88 passed, 1 failed. `USBDeviceInfoTests/timeoutIsAnExplicitUnresolvedState()` failed; this unchanged USB timeout test is outside the toolbar code path. Window chrome, layout, rendering, and full-screen restoration tests passed. Whitespace checks passed.

### Remaining Risks or Follow-up Work

- The computer-use session did not reliably complete the requested exit action, so ordinary-window toolbar restoration was not independently confirmed visually in this run. Existing restoration logic is unchanged. Older macOS and continuous transition validation remain outstanding.


## 2026-09-05 — Restore Full-Screen Edge Controls

### Summary

- Replace permanent toolbar hiding with AppKit's `autoHideToolbar` and `autoHideMenuBar` presentation options, preserving forwarded delegate options and valid Dock combinations. Prepare native controls before AppKit detaches the toolbar.
- Start full screen with a temporary hidden sidebar, independent of ordinary-window preferences. Reveal it at the leftmost 8 points or with the native toolbar toggle; keep it available while the pointer is in the sidebar or top control region, and hide it 0.5 seconds after leaving.
- Animate the sidebar over the complete aspect-fit preview without shifting or resizing video. Restore the pre-full-screen sidebar on exit. Observe local pointer events in both the content and detached native toolbar windows.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Canonical Debug build and launch: Passed.
- Focused `WindowChromeInteractionTests`: All 10 tests passed in both runners, 20 successful executions. The added test covers valid full-screen presentation options, three left-edge reveal/delayed-hide cycles, unchanged video bounds, the sidebar toggle, and restored ordinary controls and geometry.
- Strict Swift-format lint on changed Swift files and Git whitespace checks: Passed.
- Connected iPhone: Native full-screen entry completed; the toolbar was observed hidden after pointer movement. A pointer gesture to the left edge revealed the sidebar; movement away and the hide delay removed it. Video remained centered at the same size. Activating the accessible toolbar toggle collapsed the sidebar.
- The computer-use tool provides click and drag actions but no pure-hover action. Top-edge attempts did not conclusively establish a complete physical top-hover reveal cycle. No screenshots of phone content were stored in the repository.
- Full regression suite and Release build: Not run for this change. The previous unchanged USB query timeout test failure remains unverified.

### Remaining Risks or Follow-up Work

- Confirm pure top-edge hover/reveal and physical exit restoration, especially on macOS 14/15. The native auto-hide contract and presentation options are covered by Apple's API documentation and regression assertions; they do not replace physical hover acceptance.


## 2026-09-05 — Keep Full-Screen Sidebar Below the Toolbar

### Summary

- Derive the full-screen sidebar's top inset from `NSWindow.contentLayoutRect`, subtracting only the native toolbar's actual occupied height.
- Observe changes to that KVO-compliant rectangle so the sidebar and divider respond to native toolbar reveal/hide without moving the toolbar, resizing the outer window, or changing the full-screen preview rectangle. Remove the observer when the host detaches.
- Keep the app-owned titlebar background hidden in full screen to avoid duplicating native chrome.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- All 10 `WindowChromeInteractionTests`: Passed. Extended the existing full-screen test with observable unobscured-content changes at 0, 20, 42, 60, 20, and 0 points; verified sidebar top/bottom placement and unchanged video/window geometry. Initial exact floating-point comparisons failed despite identical rounded values; a one-millionth-point tolerance fixed the assertion.
- Canonical Debug build and launch, strict Swift-format lint on changed files, and Git whitespace checks: Passed.
- Connected iPhone: Show Sidebar displayed the Devices header and complete device row below the visible native toolbar; the toolbar remained at its existing top position. A left-edge gesture also revealed the sidebar below the still-visible toolbar. No phone screenshots were saved in the repository.
- Full regression suite and Release build: Not run. Existing unrelated USB timeout failure was not rerun.

### Remaining Risks or Follow-up Work

- Pure-hover toolbar hiding and the resulting physical return to a zero sidebar inset were not conclusively reproduced with computer use; zero-inset restoration is covered by the KVO integration fixture. Older macOS and continuous transition acceptance remain outstanding.


## 2026-09-05 — Explicitly Auto-Hide the Full-Screen Toolbar

### Summary

- Fix full-screen layout commits forcing the native toolbar visible regardless of pointer position. Add a separate toolbar hover state and cancellable half-second hide delay.
- Reveal the toolbar in the topmost 8 points, retain it within its measured control area, and hide it after leaving. Left-edge sidebar changes do not reveal the toolbar. Cancel pending work on full-screen lifecycle changes and detach.
- Preserve native menu-bar presentation, sidebar inset observation, and full-screen video geometry.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- All 10 window chrome interaction tests: Passed. The full-screen regression now checks initial toolbar hiding, top-edge reveal, delayed hiding after pointer departure, and repeated sidebar reveals that leave the toolbar hidden. Existing inset and geometry assertions passed.
- Canonical Debug build/launch, strict Swift-format lint, and Git whitespace checks: Passed.
- Connected-iPhone runtime: An initial visible top strip was followed by a screenshot with the complete preview reaching the top and no toolbar or white strip. The accessibility tree likewise contained no toolbar controls.
- Scripted drag attempts returned `noWindowsAvailable`, including after refreshing the app connection. These failed tool actions are not counted as successful physical pointer gestures; the observed hidden endpoint is separate evidence.
- Release build and full regression suite: Not run. The earlier unrelated USB timeout failure remains unverified.

### Remaining Risks or Follow-up Work

- Complete an uninterrupted physical top-edge hover round trip and older-macOS acceptance. Pointer transitions are covered by the integration fixture, while the tool-limited live check confirms the hidden endpoint only.


## 2026-09-05 — Use the Native Full-Screen Toolbar Policy

### Summary

- Put the sidebar button in a unified-compact native toolbar so it shares the window-control row. Configure the SwiftUI window owner with `windowToolbarFullScreenVisibility(.onHover)` on macOS 15 and later; retain AppKit full-screen presentation options for macOS 14 compatibility.
- Remove the manual full-screen toolbar hover state, hide timer, and pointer-driven visibility mutations. Leave toolbar timing, animation, and native button opacity to AppKit after one-time full-screen entry preparation. Keep the existing ordinary-window compact behavior and left-edge sidebar overlay.
- Update only sidebar/control frames in response to full-screen toolbar inset notifications, skipping this work when the sidebar is hidden. Do not reassign unchanged toolbar labels or update the preview layer from those inset callbacks.
- Replace the manual-hide test expectation with a check that full-screen pointer/sidebar changes never rewrite native toolbar visibility. Verify the unified-compact toolbar stays clear of native window controls. Correct an older restoration assertion: native toolbar overlay height can be nonzero, while external video insets remain zero.

### Affected Files

- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Views/DisplayWindowScene.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Final full Debug regression suite: Passed 91 tests, zero failures and zero skips, confirmed by `xcresulttool get test-results summary`. The first broad run had 90 passes and one outdated assertion requiring zero toolbar overlay height; the corrected assertion preserves the actual requirement of zero external video inset. The earlier unrelated USB timeout test passed in the final suite.
- Canonical Debug build and launch, strict Swift-format lint on changed Swift files, and Git whitespace checks: Passed.
- Connected iPhone: Observed the compact native control row, entered native full screen, and moved the pointer into the black preview margin. The following screenshot showed the toolbar and white strip hidden with the complete preview occupying the full-screen height. Native View-menu full-screen actions remained available. No phone screenshots were stored in the repository.
- Continuous frame pacing and a pure-hover reveal/hide recording: Not run. Computer-use snapshots and click/drag actions do not measure animation smoothness. Release build and macOS 14/15 hardware checks: Not run for this change.

### Remaining Risks or Follow-up Work

- Confirm perceived smoothness in repeated physical hover cycles and validate the macOS 14 fallback when available. Automated noninterference and geometry checks are not a frame-by-frame performance measurement.

### API References

- [SwiftUI full-screen toolbar visibility](https://developer.apple.com/documentation/swiftui/windowtoolbarfullscreenvisibility)
- [AppKit auto-hide toolbar presentation option](https://developer.apple.com/documentation/appkit/nsapplication/presentationoptions-swift.struct/autohidetoolbar)

## 2026-09-05 — Audit Code, Native APIs, and Validation Coverage

### Summary

- Review all 20 production Swift files, eight Swift test files, three developer scripts, Xcode configuration, and resource-generation validation at baseline `397b1f9`.
- Record nine prioritized findings and native-component recommendations in `code-audit-2026-09-05.md`. Reproduce six source-state/window issues in a temporary project copy; identify the capture interruption recovery defect through source tracing and the installed SDK contract.
- Identify unused geometry/model helpers, duplicate discovery work, and responsibilities that can be separated after behavior fixes. Verify macOS API availability before recommending substitutions; `isPreviewing`, `isInterrupted`, and the named media-services-reset error are not direct macOS replacements.
- Update current constraints and validation results. Clarify that retry delays are capped but attempts are not limited. Application behavior and production/test source files remain unchanged.

### Affected Files

- `doc/code-audit-2026-09-05.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Existing full Debug regression: 91 tests, 90 passed, one failed, zero skipped. `USBDeviceInfoTests/timeoutIsAnExplicitUnresolvedState()` still saw `.identifying` after its fixed 30 ms sleep. Result bundle: `/tmp/USBDisplay-Audit-Debug-Allowed-20260905.xcresult`.
- Isolated USB identity suite: Nine passed, zero failures/skips, including the same timeout test. This supports a timing-dependent test failure; it does not establish a socket-timeout defect. Result bundle: `/tmp/USBDisplay-Audit-USB-Suite-20260905.xcresult`.
- Temporary regression probes: Six unique tests failed the corrected-behavior expectations and reproduced source-ratio caching, obsolete snapshot acceptance, non-live resize restoration, failed full-screen cleanup, smaller-screen fitting, and stale appearance colors. The copied project only exposed two private members without changing production method bodies. Diagnostic tests are outside the repository at `/tmp/usbdisplay-code-audit-20260905`; result bundle: `/tmp/USBDisplay-Audit-Probes-Final-20260905.xcresult`.
- Normal Release build for arm64 and x86_64, strict deep signature verification, nine Python tests, offline catalog verification, strict recursive Swift-format lint, shell syntax, plist/project syntax, and Git whitespace checks: Passed.
- Release Analyze: Failed because the shared scheme includes unit tests whose `@testable import` requires a Release app module built with testability. Normal Release build was checked separately and passed.
- Initial sandboxed Debug build: Blocked by Swift macro execution; repeated through permitted Xcode execution. Two function-level test selectors matched zero tests and are excluded from validation. The first temporary harness had a Swift Testing macro syntax error, fixed before its six probes executed.
- Physical capture/device switching, monitor removal, TCC permission changes, native Zoom/tiling acceptance, continuous interaction recording, older macOS runtime checks, and Instruments profiling: Not run. The canonical run script was reviewed and syntax-checked; no normal-app relaunch through that script was performed.

### Remaining Risks or Follow-up Work

- Implement and validate the nine findings in focused changes. No audit finding is claimed as fixed by this documentation commit.
- Confirm capture interruption/recovery and permission-change behavior on hardware, then complete the existing multi-device, monitor, full-screen, and frame-pacing acceptance work. Temporary event/state injection is not physical acceptance.

## 2026-09-05 — Fix Capture Generations and Native Window Lifecycle

### Summary

- Implement audit findings F1–F9 and the approved Apple-component cleanup while retaining macOS 14+, the AVFoundation/CoreMediaIO direct-preview pipeline, continuous masks, per-window capture ownership, and native full-screen toolbar behavior.
- Make the model own selection and request identity. Tag capture snapshots with request, stream, and sequence, and reject stale or reordered delivery. Reset ratio stabilization for each video source while preserving the session and preview layer.
- Separate a queue-confined capture state machine from its AVFoundation driver. Inject event/delay scheduling for deterministic tests. Invalidate stale startup confirmations/events/retries, restore interrupted sessions after revalidation, and re-evaluate only the active request when camera authorization completes.
- Preserve valid non-live window resizes, including native Zoom during chrome animation. Fit the displayed video to new screen bounds separately from the preferred size; handle screen-parameter changes and defer updates during drag/full-screen transitions. Recover failed full-screen entry/exit through official forwarded delegate callbacks.
- Use SwiftUI device-row buttons, ContentUnavailableView, and effective-appearance color refresh. Retain the connecting ProgressView and existing user guidance. Extract native toolbar, window event/delegate bridge, and hover scheduling while keeping geometry state in one host.
- Deduplicate equal raw discovery values and retain a capture discovery session. Preserve five-second identity refresh and conservative complete-snapshot association. Remove the confirmed unused models/helpers/logger, superseded retry helper, duplicate constants, and unreachable layout branches.
- Replace fixed USB-test completion sleeps with bounded signals and controlled query completion. Exclude tests from Analyze without enabling shipping Release testability. Replace obsolete self-only helper tests with production-path capture/window regressions, including the six original temporary reproductions.
- Update current state and mark actual implementation, validation, and physical limits in the audit report.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplay.xcodeproj/xcshareddata/xcschemes/USB Display.xcscheme`
- `USBDisplay/Models/CaptureFailure.swift`
- `USBDisplay/Models/ConnectionStatus.swift`
- `USBDisplay/Models/DisplayCornerProfile.swift`
- `USBDisplay/Models/DisplayDevice.swift`
- `USBDisplay/Models/ResizeSession.swift`
- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Services/AVFoundationCaptureDriver.swift`
- `USBDisplay/Services/AppModel.swift`
- `USBDisplay/Services/CaptureCoordinator.swift`
- `USBDisplay/Services/DeviceCatalog.swift`
- `USBDisplay/Services/USBDeviceInfoService.swift`
- `USBDisplay/Support/AppLogger.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/DisplayCanvasView.swift`
- `USBDisplay/Views/PreviewView.swift`
- `USBDisplay/Views/SidebarToolbarDelegate.swift`
- `USBDisplay/Views/SidebarView.swift`
- `USBDisplay/Views/WindowEventBridge.swift`
- `USBDisplay/Views/WindowHoverScheduler.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/CaptureFailureTests.swift`
- `USBDisplayTests/CaptureStateTests.swift`
- `USBDisplayTests/DisplayCornerProfileTests.swift`
- `USBDisplayTests/USBDeviceInfoTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/WindowLifecycleTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/code-audit-2026-09-05.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Final Debug suite: Passed 100 tests with zero failures and zero skips. Result: `/tmp/USBDisplay-Fixes-Final-20260905.xcresult`; counts verified through `xcresulttool get test-results summary`.
- Earlier focused run: Passed 26 tests. Initial full run: Passed 99 tests. One more regression was added for a legitimate non-live resize during an unfinished chrome animation; its fix and the final full suite passed. Early compile errors in a generated state initializer and mutating Swift Testing assertions were corrected before the successful runs.
- Universal Release build and Release Analyze: Passed with arm64 and x86_64 confirmed by `lipo`; no `-enable-testing` or unit-test target in the final Release compilation log. Log: `/tmp/USBDisplay-Fixes-Release-Final-20260905.log`.
- Python catalog suite: Passed nine tests using `python3 -m unittest discover -s script -p 'test_*.py' -v`. Offline `python3 script/update_device_profiles.py --check`: Passed. No generated resources changed.
- Strict recursive Swift-format lint, shell syntax, project/Info.plist/entitlements syntax, Git whitespace, and strict deep Debug/Release ad-hoc signature verification: Passed. Xcode emitted the expected no-AppIntents metadata-extraction notice; no unused framework was added.
- Canonical `./script/build_and_run.sh --verify`: Passed, repeated after the final source change. Final launch log: `/tmp/USBDisplay-Fixes-Run-Final-20260905.log`.
- Live iPad Pro (11-inch, M4): Observed changing video content with the new capture driver. A temporary unselected window displayed the native selection state; right-click opened its context menu and left it unselected, and primary click focused the existing capture window. Native sidebar controls, View-menu full-screen entry/exit, settled toolbar auto-hide, and native Zoom followed by a sidebar round trip were exercised. The temporary window was closed. The final relaunched app also displayed the connecting ProgressView before returning to capture.
- The UI tool required fresh state around auto-hiding controls and had one transient ScreenCaptureKit screenshot error during a full-screen transition; settled state was read successfully. A right-edge drag attempt did not establish a changed size and is not counted as successful physical resize validation.
- The six baseline defects are now tested through controlled public/internal production interfaces, not by opening private members. Both full-screen failure directions, negative/smaller-screen fitting and restoration, deferred screen changes, resize-before-screen-event ordering, and Aqua/Dark Aqua callbacks are covered. Existing continuous-alpha, stable-layer, eight-handle, animation, toolbar noninterference, and independent-window tests passed.

### Remaining Risks or Follow-up Work

- Only one capture source was listed. Physical equal-ratio two-device switching, forced interruption/occupied-device recovery, rotation, hot unplug/replug, external-screen removal/restoration, and TCC changes were not performed. System-wide appearance switching was not performed; its callbacks were validated in AppKit fixtures.
- The no-device and failure components compile and preserve descriptions, but live interaction checks exercised selection/connecting and active capture without unplugging hardware or changing privacy permissions.
- Continuous WindowServer recording, exhaustive physical edge/corner drags, repeated hover/resize interleaving, 20 physical sidebar cycles, native-resolution/latency/frame-rate benchmarks, macOS 14/15 runtime acceptance, multi-window soak, production signing, and notarization remain outstanding. Automated and endpoint checks do not prove those properties.
- Keep ratio polling until real USB port format/rotation-event evidence supports replacing it. usbmuxd/lockdownd identity is still an isolated, unsupported-by-Apple-public-SDK protocol path. The optional permission-settings retry/relaunch behavior identified in the audit is unchanged.

### Final Runtime Clarification

- After the final canonical launch, the UI remained connecting until AVFoundation logged startup at 21:20:43, approximately two minutes after the 21:18:44 launch. App discovery subsequently reported zero devices at 21:20:46 and one device at 21:20:55. The final UI identified an iPhone 16 Pro and displayed live portrait content with proportional window geometry; the earlier interaction acceptance used an iPad Pro (11-inch, M4).
- Only one source was listed at a time. The observed device transition is not a controlled equal-ratio switch, hot-plug, or latency test. The cause of the initial wait was not isolated to permission, device, or system state. A brief thread sample occurred after startup resumed and did not identify the earlier blocking call. No privacy setting or cable was changed by the agent.
- The final running app is usable, but controlled startup/first-frame timing remains an outstanding hardware investigation. Current state and the audit report include this limit; no additional pipeline change was made on speculative evidence.

## 2026-09-05 — Use the Default Native Sidebar Toolbar Item

### Summary

- Replace the custom NSButton toolbar view with a standard image-based NSToolbarItem using its public image, target, and action properties. Remove the textured-rounded bezel and fixed 32-by-28-point size; AppKit now creates and sizes the control with its default appearance.
- Remove app-owned opacity and layer transforms for the toolbar button. Preserve ordinary-window toolbar visibility, window-button fades, sidebar layout, and AppKit-owned full-screen behavior.
- Keep the existing Show Sidebar / Hide Sidebar labels and tooltips. Adapt the traffic-light spacing regression to read the system-generated button's public accessibility frame instead of a custom view.
- Implementation follows Apple's [NSToolbarItem documentation](https://developer.apple.com/documentation/appkit/nstoolbaritem); the local SDK confirms that automatically generated items return nil for their custom view.

### Affected Files

- `USBDisplay/Views/SidebarToolbarDelegate.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Passed 25 focused Debug tests with zero failures and zero skips across WindowChromeInteractionTests, WindowLifecycleTests, and WindowRenderingTests. Result: `/tmp/USBDisplay-NativeToolbar-Window-20260905.xcresult`. Coverage includes toolbar spacing throughout repeated chrome transitions, full-screen toolbar noninterference, lifecycle recovery, and stable preview rendering.
- An initial test compilation used the Objective-C accessibility protocol name; corrected it to Swift's NSAccessibilityProtocol before the successful run. xcresulttool required access to its report cache; its successful summary confirmed the final counts.
- Passed `./script/build_and_run.sh --verify`; log: `/tmp/USBDisplay-NativeToolbar-Run-20260905.log`. Strict Swift-format lint for the changed Swift files, Debug strict deep signature verification, and Git whitespace checks passed.
- Inspected the running application and activated the system toolbar item: ordinary-window collapse and full-screen expansion updated the sidebar and accessibility labels. Entered and exited native full screen, returning to the ordinary compact window. A settled full-screen screenshot showed the sidebar overlay after expansion.
- The UI tool reported noWindowsAvailable for ordinary-window coordinate clicks while accessibility access still worked. Menu and accessibility actions completed the interaction checks. Early full-screen screenshots were transitional and were not used as settled-layout evidence.

### Remaining Risks or Follow-up Work

- The button's exact shape follows the running macOS version and toolbar context; the app imposes no circular shape or dimensions. macOS 14/15 runtime appearance was not checked.
- Release, the complete Debug suite, Python tests, and resource verification were not rerun for this toolbar-only change; the prior audit validation remains recorded above. This check used an unselected window with a discovered iPhone and did not repeat live capture or hardware acceptance.

## 2026-09-05 — Fix Sidebar Toggle Overlap During Toolbar Reveal

### Summary

- Reproduce the reported overlap between the standard sidebar item and native window buttons after compact-mode reveal. Making the window buttons briefly opaque before showing the toolbar was insufficient: the app restored zero opacity before AppKit's deferred layout measured them.
- Remove app-owned window-button opacity changes, including cleanup writes. Ordinary compact mode still hides/unhides the buttons before changing toolbar visibility. Keep the standard toolbar item's default appearance and dimensions, app-owned background/sidebar animation, and native full-screen handling.
- Extend the real SwiftUI window regression with three compact/reveal cycles sampled across deferred layout without forcing a layout pass. Retain the separate synchronous spacing fixture and require native window buttons to retain their default opacity.

### Affected Files

- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Before the fix, the rendering suite passed five tests and failed the extended real-window regression. Its accessibility rectangles confirmed that the sidebar item intersected the native controls. Result: `/tmp/USBDisplay-ToolbarOverlap-Reproduce-20260905.xcresult`.
- After the fix, all 25 selected window interaction, lifecycle, and rendering tests passed with zero failures and zero skips. Result: `/tmp/USBDisplay-ToolbarOverlap-Fixed-20260905.xcresult`; counts confirmed through xcresulttool. An initial method-only filter selected zero tests and was not treated as a passing reproduction.
- Passed `./script/build_and_run.sh --verify`, strict Swift-format lint for changed Swift files, Debug strict deep signature verification, and Git whitespace checks. Launch log: `/tmp/USBDisplay-ToolbarOverlap-Run-20260905.log`.
- Reproduced the visible overlap in a temporary empty window. Final interaction in the repaired build confirmed compact-mode reveal places the sidebar item to the right of the native window-control area, and its action expands the sidebar. Closed the temporary window and observed the selected iPhone preview again.
- UI automation initially encountered timeouts and ambiguous app resolution because three copies were running from Xcode DerivedData, the canonical `.build/Xcode` directory, and `.build/Audit`. Closed the stale copies, including stopping Xcode's retained debug session after normal termination did not release it. Verified that only the canonical process remained before accepting the final UI evidence.

### Remaining Risks or Follow-up Work

- Release, unrelated test suites, macOS 14/15 runtime appearance, and exhaustive physical resizing/full-screen cycles were not repeated for this focused fix. Prior hardware and performance limits remain unchanged.

## 2026-10-07 — Add a Mac and iPhone USB-C Icon Concept

### Summary

- Generate a blue rounded-square icon concept showing a Mac display and an iPhone joined by a white USB-C cable, following the requested revision to the initial single-phone concept.
- Save the generated PNG and exact built-in imagegen prompt for further design work. The application icon and build configuration are unchanged.

### Affected Files

- `doc/design/usb-display-icon-mac-iphone-v2.png`
- `doc/design/usb-display-icon-mac-iphone-v2-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually inspected the generated concept: the Mac and iPhone are distinct, and one cable joins both devices below their screens.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels and has an alpha channel.
- Build and tests: Not run; this change adds design material only.

### Remaining Risks or Follow-up Work

- This is a generated design concept. Production icon sizing, alpha-edge cleanup, small-size validation, and application integration have not been performed.

## 2026-10-07 — Revise the Icon Concept to Use a MacBook

### Summary

- Add a new icon concept with a MacBook and iPhone, using the user's supplied pictograms for the laptop notch, slim base, phone silhouette, Dynamic Island, and home indicator.
- Preserve the blue tile and USB-C connection, with the cable entering the MacBook from the side. Retain the earlier concept as a separate file and save the final generation prompt.

### Affected Files

- `doc/design/usb-display-icon-macbook-iphone-v3.png`
- `doc/design/usb-display-icon-macbook-iphone-v3-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually inspected the selected image for the laptop base, screen notch, iPhone silhouette, and single cable connecting both devices.
- Two preliminary image edits retained an unwanted transparent patch beneath the laptop. A fresh generation removed that visible interior defect; only the selected final image was added to the repository.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels and has an alpha channel.
- Build and tests: Not run; application code and resources used by the build were not changed.

### Remaining Risks or Follow-up Work

- Production icon sizing, residual alpha-edge cleanup, small-size validation, and application integration remain pending.

## 2026-10-07 — Correct Icon Cable Placement and Transparent-Edge Artifacts

### Summary

- Add a fresh MacBook and iPhone concept with the laptop's right chassis wall visible, placing the USB-C connector near the hinge and retaining the iPhone's bottom-center connection.
- Simplify the generated laptop by removing individual keyboard keys, metallic detail, and phone side buttons. Keep the blue, navy, pale-blue, and white design direction.
- Use an opaque blue square to remove the earlier transparent-edge speckling. Preserve previous concepts and save both generation prompts.
- Correction to the preceding entry: v3 did not clearly depict a chassis-side port; its front-facing base endpoint made the cable placement ambiguous. Its alpha-edge artifacts remained visible and were reported by the user.

### Affected Files

- `doc/design/usb-display-icon-macbook-iphone-v4.png`
- `doc/design/usb-display-icon-macbook-iphone-v4-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually inspected the final source for a connector on the laptop's visible side wall, the iPhone bottom-center connection, a continuous cable, and absence of the previous exterior colored speckles.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels and has no alpha channel.
- Build and tests: Not run; the change adds design material only and does not change application code or the build configuration.

### Remaining Risks or Follow-up Work

- This remains a generated raster concept. Production sizing, application icon masking, small-size validation, and application integration remain pending.

## 2026-10-07 — Use Flat iPad and iPhone Silhouettes with Separate Cables

### Summary

- Replace the current design direction with front-facing iPad and iPhone pictograms, following the user's request to remove the Mac and all perspective geometry.
- Show one independent white USB-C cable entering the bottom center of each device. Keep the tablet upright, the blue background opaque, and the earlier concepts in separate files.
- Save the selected PNG and its exact built-in imagegen prompt.

### Affected Files

- `doc/design/usb-display-icon-ipad-iphone-v5.png`
- `doc/design/usb-display-icon-ipad-iphone-v5-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually inspected the generated source: a larger iPad and smaller iPhone face directly forward, with two separate bottom-connected cables and no Mac or angled device surfaces.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels and has no alpha channel.
- Build and tests: Not run; application code, build resources, and configuration are unchanged.

### Remaining Risks or Follow-up Work

- Production sizing, application icon masking, small-size validation, and application integration remain pending for this raster concept.

## 2026-10-07 — Overlap the iPad and iPhone and Remove Cables

### Summary

- Remove both cables and plug housings from the icon concept at the user's request.
- Position the iPhone in front of the iPad's lower-right side with a small overlap and narrow blue separation boundary. Keep the device silhouettes flat and front-facing.
- Save the new PNG and exact imagegen edit prompt while retaining earlier versions.

### Affected Files

- `doc/design/usb-display-icon-ipad-iphone-v6.png`
- `doc/design/usb-display-icon-ipad-iphone-v6-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually inspected the output for the requested overlap, clearly separated device silhouettes, and removal of both cables and plugs.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels and has no alpha channel.
- Build and tests: Not run; this change affects design material only.

### Remaining Risks or Follow-up Work

- Production sizing, application icon masking, small-size validation, and application integration remain pending.

## 2026-10-07 — Remove Screen Marks and the Overlap Separation Seam

### Summary

- Remove the iPhone Dynamic Island and both home indicators, leaving blank screens.
- Remove the artificial blue separation seam so the foreground phone visually occludes the iPad without carving a gap in its visible outline.
- Attempt the requested 3–5-pixel move to the lower right. Retain the closest generated result and document its measured placement rather than claiming exact translation.

### Affected Files

- `doc/design/usb-display-icon-ipad-iphone-v7.png`
- `doc/design/usb-display-icon-ipad-iphone-v7-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually inspected blank screens and removal of the blue gap. The output is flattened raster artwork; it does not provide an independently editable complete iPad layer.
- A read-only Pillow measurement using `R < 60`, `G < 85`, and `B < 110` found v6 dark bounds `(193, 181, 1061, 1025)` and selected v7 bounds `(197, 187, 1057, 1034)`. The top-left anchor shifted right 4 pixels and down 6 pixels, with slight changes to overall dimensions.
- A further generative correction moved the group upward too far and was not selected. The exact 3–5-pixel rigid movement remains unfulfilled.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels with no alpha channel.
- Build and tests: Not run; this change affects design material only.

### Remaining Risks or Follow-up Work

- Exact pixel placement and layered source geometry remain unresolved. Production sizing, application icon masking, small-size validation, and application integration remain pending.

## 2026-10-07 — Restore the Dynamic Island and Home Indicators

### Summary

- Restore the iPhone Dynamic Island and the bottom home indicators on both devices at the user's request.
- Retain the flat overlapping iPad and iPhone composition without a blue separation seam, and save the new PNG and exact imagegen edit prompt.

### Affected Files

- `doc/design/usb-display-icon-ipad-iphone-v8.png`
- `doc/design/usb-display-icon-ipad-iphone-v8-prompt.md`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Visually verified one pill at the top of the iPhone screen, one home indicator in each screen, and the retained foreground-phone overlap.
- Confirmed with `sips` that the saved PNG is 1254 by 1254 pixels and has no alpha channel.
- Build and tests: Not run; this change affects design material only. Exact pixel placement was not revalidated.

### Remaining Risks or Follow-up Work

- Exact placement, layered source geometry, production sizing, application icon masking, small-size validation, and application integration remain pending.

## 2026-10-07 — Reconstruct the Device Icon as Editable SVG

### Summary

- Reconstruct the v8 design as native SVG geometry with eight rounded or square rectangles and three solid fills, preserving its device arrangement, Dynamic Island, and both home indicators.
- Keep complete iPad and iPhone groups in back-to-front paint order. Add stable element IDs and a shared translation transform for exact future positioning. The current conversion follows v8 without another offset.
- Preserve the original PNG and save a separate PNG preview rendered from the SVG. The SVG contains no embedded raster content, scripts, or external references.

### Affected Files

- `doc/design/usb-display-icon-ipad-iphone-v8.svg`
- `doc/design/usb-display-icon-ipad-iphone-v8-vector-preview.png`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Parsed the SVG as XML and checked its 1254-by-1254 viewBox, unique IDs, eight vector rectangles, complete iPad frame, and iPad-before-iPhone group order. Confirmed there are no image elements, scripts, or external resource references.
- Rendered a 1254-by-1254 PNG through macOS Quick Look and visually inspected the overlap, smooth outlines, three screen indicators, and flat fills. The first Quick Look attempt failed because of its sandbox initialization; the retry with the approved permission completed successfully.
- Build and application tests: Not run; this change only adds design assets and documentation.

### Remaining Risks or Follow-up Work

- The SVG is a geometric reconstruction with uniform fills, not a pixel-identical trace of the generated PNG's texture. Production icon sizes and masking, small-size review, and application integration remain pending.

## 2026-10-07 — Use the Approved Device Artwork as the Application Icon

### Summary

- Add `Assets.xcassets` and a complete macOS `AppIcon.appiconset`, generated directly from the approved v8 SVG without changing its device artwork.
- Add a native AppKit export script that renders ten sRGB PNG variants from 16 through 1024 pixels, with 1x and 2x slots for each macOS point size. The script requires no third-party image library.
- Include the asset catalog in the app target's resource phase and select AppIcon for both Debug and Release. Xcode supplies the generated bundle icon metadata; the source Info.plist needs no manual icon key.
- Follow Apple's [asset catalog configuration guidance](https://developer.apple.com/documentation/xcode/configuring-your-app-icon) and [app icon shape guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons). Read the installed Xcode 27 documentation and the macOS build/run skill; no matching icon-specific Apple-exported skill was available.

### Affected Files

- `USBDisplay/Resources/Assets.xcassets/Contents.json`
- `USBDisplay/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- All ten PNG files in `USBDisplay/Resources/Assets.xcassets/AppIcon.appiconset/`
- `script/generate_app_icon.swift`
- `USBDisplay.xcodeproj/project.pbxproj`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Passed `./script/build_and_run.sh --verify`; the new Debug app built, relaunched, and passed the process-running check. Log: `/tmp/USBDisplay-AppIcon-20261007.log`.
- Passed the Release build using the same project, scheme, and `.build/Xcode` derived data. Log: `/tmp/USBDisplay-AppIcon-Release-20261007.log`. These builds emitted the expected no-AppIntents metadata-extraction warning and no icon compiler warnings.
- Verified Debug and Release Info.plist values for `CFBundleIconName` and `CFBundleIconFile`, along with the generated `AppIcon.icns` and `Assets.car` files. Both bundles passed `codesign --verify --deep --strict`.
- Checked all ten catalog entries against their actual PNG dimensions and confirmed fully opaque source pixels. A second export produced byte-identical assets on this toolchain. Swift-format strict lint, project plist validation, and Git whitespace checks passed.
- Visually inspected the rendered artwork and the actual Debug application's small header icon and large preview in Finder's information window on macOS 27.0.1. The system displayed the approved device pair with its rounded icon presentation.
- Direct Dock inspection timed out, so visual verification used Finder instead. An initial sandboxed process-list read was unavailable; the approved canonical build/run script completed its own process check successfully.
- Application unit tests: Not run; this change only adds icon resources, export tooling, and target resource configuration. Live capture functionality was not revalidated.

### Remaining Risks or Follow-up Work

- Icon presentation on macOS 14/15 and distribution/App Store acceptance were not tested. Production signing and notarization remain outside this task. Native SVG rasterization is tied to the installed macOS AppKit implementation; regenerated files should be reviewed after toolchain changes.


## 2026-11-11 — Stabilize Hover Controls and Add Native Sidebar Resizing

### Summary

- Change the ordinary connected window's transient hover toolbar to an overlay. Revealing and hiding it no longer reserves titlebar space or changes the window/video rectangles, including when the window touches the top screen edge. The overlay temporarily covers the top of the video while controls are visible.
- Use the standard-height unified toolbar instead of unified compact. Keep the existing system-generated image item, with no custom circular background, button size, or bezel. The running application now presents the sidebar button as a circle on the current macOS version.
- Replace the decorative sidebar separator with an AppKit `NSSplitView`, retaining native divider drawing, hit testing, cursor feedback, accessibility positioning, and gesture recognition. Keep the persistent video outside the split view; its transparent trailing pane passes input through.
- Store the user's sidebar width per window. Untouched placeholder windows keep their 30/70 split; untouched connected windows retain a 220-point sidebar. User widths normally range from 160 to 480 points and are constrained by available space. Connected divider changes retain video size and the left window edge; placeholder changes retain window size; full-screen changes retain the full video rectangle.
- Suspend hover and source-geometry publication during a divider gesture, and retain the selected width across sidebar hide/show. Distinguish native divider changes from ordinary split-view layout notifications to avoid feedback into window geometry.
- Consult the installed Xcode 27.2 AppKit/HIG documentation and the Apple-native-design/macOS window-management, AppKit interop, and build/run skills. The relevant public APIs are [unified toolbar style](https://developer.apple.com/documentation/appkit/nswindow/toolbarstyle-swift.enum/unified) and [NSSplitView](https://developer.apple.com/documentation/appkit/nssplitview). The exported Apple app-resizability skill targets UIKit and was not applied to this macOS fix.

### Affected Files

- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Services/AppModel.swift`
- `USBDisplay/Views/ContentView.swift`
- `USBDisplay/Views/SidebarSplitView.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplay.xcodeproj/project.pbxproj`
- `USBDisplayTests/WindowInteractionTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/WindowLifecycleTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- All 104 Debug tests in 14 suites passed on Xcode 27.2. Log: `/tmp/USBDisplay-toolbar-tests-3.log`. New regressions cover native divider positioning, retained width, unchanged video size/layer identity, full-screen overlays, and window/video screen coordinates through deferred hover layout at the top screen edge.
- Initial runs exposed split-layout notification feedback and a zero-size initial pane layout; both were corrected. Updated the pixel-edge rendering check to account for the intentionally covered top edge during hover. Final test logs contain no split-layout inconsistency or disabled-gesture-recognizer warnings.
- `./script/build_and_run.sh --verify` passed, relaunching the canonical Debug bundle. Log: `/tmp/USBDisplay-toolbar-run.log`. Strict Swift-format lint on changed Swift files, project plist validation, strict deep Debug signature verification, and Git whitespace checks passed.
- Native desktop inspection with the dedicated Terra ultra agent confirmed a live iPad feed without a permission prompt, a round sidebar button, and successful sidebar toggle actions. Accessibility adjustments changed the divider from 220 to 300 and 180 points, with corresponding window widths and the same video-region width, then restored 220 points.
- Hidden/revealed toolbar screenshots both measured 1460 by 1006 pixels. The iPad content changed during inspection, preventing a controlled comparison of fixed video markers. Desktop-tool mouse drags did not produce a reliable endpoint; these attempts are not counted as successful physical drag validation.
- Release build and older macOS runtime checks: Not run.

### Remaining Risks or Follow-up Work

- Verify continuous physical mouse drags on the sidebar divider, including screen-edge limits and full screen. The native accessibility tree reports the splitter as disabled but settable; its value-setting path works, while direct pointer behavior could not be established with the desktop tool.
- WindowServer frame-by-frame smoothness and pixel-level stability of a stationary physical video source remain unverified. Automated geometry and synthetic rendering checks do not establish those properties.
- macOS 14/15 appearance and interaction behavior remain unverified. Sidebar widths are remembered only for the lifetime of each window.


## 2026-11-11 — Restore Upward Toolbar Reveal and Correct Native Height Measurement

### Summary

- Correct the preceding entry's design decision: the user requires hover controls to expand above the existing video, preserving the original interaction. Remove the unconditional ordinary-hover overlay and its now-unused policy parameter. Keep native circular toolbar styling and sidebar resizing.
- Restore outside titlebar reservation for ordinary connected windows. With enough room above the video, the window grows upward and the video keeps its screen position and size. Preserve the existing screen-fitting and full-screen policies.
- Fix a separately reproduced native-height defect: the host could cache a 32-point title-only measurement before AppKit laid out the 52-point unified toolbar. The resulting 20-point shortfall covered the video edge. Complete native layout and read `contentLayoutRect` inside the existing nonanimated transaction before calculating the target geometry.
- Replace the overlay regression expectations with upward expansion, no titlebar/video overlap, and stable video coordinates through deferred native layout. Restore the synthetic top-edge pixel assertions instead of excluding the covered edge.

### Affected Files

- `USBDisplay/Models/WindowLayoutPolicy.swift`
- `USBDisplay/Views/WindowLayoutCoordinator.swift`
- `USBDisplayTests/WindowInteractionTests.swift`
- `USBDisplayTests/WindowLayoutPolicyTests.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- All 104 Debug tests in 14 suites passed after the native-height correction. Log: `/tmp/USBDisplay-upward-toolbar-tests-3.log`.
- The restored top-edge rendering assertion failed before the fix. A focused diagnostic recorded a 32-point reservation versus a 52-point actual toolbar and gray toolbar pixels at the video edge. The full pixel assertion passes after the fix. Log: `/tmp/USBDisplay-upward-render-diagnostic.log`. Temporary diagnostic prints were removed.
- The deferred-layout test verifies an unchanged video screen rectangle, unchanged window origin/width, and increased window height equal to the reserved native titlebar height throughout repeated reveal/hide cycles. Floating-point sum comparisons use a subpixel tolerance; video rectangle comparisons remain exact.
- `./script/build_and_run.sh --verify`, strict Swift-format lint on changed Swift files, strict deep Debug signature verification, and Git whitespace checks passed. Relaunch log: `/tmp/USBDisplay-upward-toolbar-run-final.log`.
- Final native inspection retained the round sidebar button, but the connected device preview was black. Hidden/revealed screenshots both measured 1460 by 1006 pixels, so this run did not demonstrate upward expansion or noncoverage of a usable physical video source. A process check confirmed one running canonical Debug app. No claim of physical-feed acceptance is made from this run.
- Release build and older macOS runtime checks: Not run.

### Remaining Risks or Follow-up Work

- WindowServer frame-by-frame smoothness of a physical video feed remains unverified. The corrected height mismatch is reproduced and fixed, but it does not prove the cause of every previously reported visual jump.
- Existing screen-edge fitting can translate a preview when there is insufficient space above it; full screen and windows taller than the available screen retain their prior overlay fallback. This correction restores the original behavior rather than introducing a new edge policy.
- The previous entry's continuous physical sidebar-drag and older macOS validation limitations remain outstanding.


## 2026-11-11 — Close the Transparent Sidebar Divider Seam

### Summary

- Fix the thin see-through line between the sidebar and preview. The native split divider rendered with alpha around 0.102 on the transparent host, exposing content behind the window.
- Draw an opaque `windowBackgroundColor` base only inside `NSSplitView`'s divider rectangle, then let AppKit draw its normal divider above it. Keep the trailing video pane transparent, native divider hit testing and dragging, sidebar width, and upward toolbar reveal unchanged.
- Add a composed-window pixel regression that samples the seam at three heights, three sidebar widths (including fractional widths), and both light and dark appearances.

### Affected Files

- `USBDisplay/Views/SidebarSplitView.swift`
- `USBDisplayTests/WindowRenderingTests.swift`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Before the fix, the new seam regression failed all 36 sampled opacity checks; the existing seven rendering tests passed. Log: `/tmp/USBDisplay-sidebar-seam-before-2.log`.
- After the fix, all eight rendering tests passed, including the seam, top video edge, transparent compact corners, deferred native toolbar layout, and persistent preview rendering. Log: `/tmp/USBDisplay-sidebar-seam-after.log`.
- `./script/build_and_run.sh --verify`, strict Swift-format lint on both changed Swift files, strict deep Debug signature verification, and Git whitespace checks passed. Relaunch log: `/tmp/USBDisplay-sidebar-seam-run.log`.
- Dedicated native desktop inspection showed a narrow dark separator with no obvious underlying page leak and retained the circular sidebar button. The preview was black during that check, so pixel opacity is established by the rendering regression rather than that screenshot alone.
- Full application test suite and Release build: Not run for this drawing-only fix.

### Remaining Risks or Follow-up Work

- Older macOS appearance and a contrasting-desktop/live-video visual comparison remain unverified. The existing sidebar fade animation is preserved; opacity checks cover the settled visible separator.


## 2026-11-12 — Package a Universal Local Release

### Summary

- Add `script/package_local_release.sh` to build version 0.3.0 (build 3) in Release mode for both Apple Silicon and Intel, then create a compressed read-only DMG and a ZIP app archive. Each run uses a new ignored output directory without replacing an earlier package.
- Include an Applications shortcut and local-installation notes in the DMG. Save SHA-256 checksums, signature metadata, and entitlements beside the packages. Verify the app after mounting the DMG and extracting the ZIP; detach the image and clean task staging directories.
- Preserve the local ad-hoc signing workflow and hardened runtime. Disable Xcode's injected base entitlements for this packaging command after inspection found an unwanted `get-task-allow` debugging entitlement. The final app has only the camera/video-capture entitlement.
- Final packages are `.build/Distribution/USBDisplay-0.3.0-build3-local.Gm0yLr/USBDisplay-0.3.0-build3-local.dmg` and `.build/Distribution/USBDisplay-0.3.0-build3-local.Gm0yLr/USBDisplay-0.3.0-build3-local.zip`. Remove the preliminary package generated during this task before the debugging-entitlement correction. Application sources remain at the preceding `c1a30ba` baseline.

### Affected Files

- `script/package_local_release.sh`
- `doc/current.md`
- `doc/devlog.md`
- Ignored `.build/Distribution/USBDisplay-0.3.0-build3-local.Gm0yLr/` package artifacts

### Validation

- Universal Release build passed on Xcode 27.2. The executable contains `x86_64` and `arm64`, declares minimum macOS 14.0, and includes the app icon. Runtime dependencies resolve to Apple system libraries/frameworks. No test bundles are embedded.
- The complete packaging script passed after correcting its architecture check to inspect `lipo -archs`. Log: `/tmp/USBDisplay-package-local-release-final.log`. The selected toolchain's multi-architecture `-verify_arch` invocation failed during initial attempts; no successful package is claimed from those attempts.
- Strict deep signature checks passed for the source app, mounted DMG copy, and extracted ZIP copy. DMG image checksums, both exported SHA-256 sums, shell syntax, and Git whitespace checks passed.
- The final DMG is 850669 bytes; the ZIP is 756165 bytes. The final entitlement dictionary contains only `com.apple.security.device.camera = true`. The app is ad-hoc signed with hardened runtime and no TeamIdentifier.
- The final Gatekeeper execution assessment returned `rejected` with exit status 3, consistent with the lack of Developer ID signing/notarization. This is not a trusted public-distribution artifact.
- The host emitted deprecation notices for `hdiutil attach/detach`; both operations succeeded. The script retains those commands for compatibility with older supported macOS development hosts.
- Application tests, packaged-Release launch, physical-device capture, and installation into Applications: Not run; this task changes packaging tooling and leaves the existing running app untouched.

### Remaining Risks or Follow-up Work

- Developer ID signing, notarization, and Gatekeeper acceptance are required before treating the package as a public release. No credentials were requested, no app was uploaded, and no public release was published.
- Test the packaged Release on physical devices and older supported macOS versions, including an Intel Mac, before distribution. Existing preview-startup, continuous-drag, and frame-pacing limitations remain.


## 2026-11-13 — Use a White Application Icon Background

### Summary

- Change the editable SVG background from blue to pure white (`#FFFFFF`) at the user's request. Preserve every device shape, position, navy frame, pale-blue screen, Dynamic Island, and home indicator.
- Regenerate all ten macOS AppIcon PNGs and the vector preview. Preserve the earlier raster concepts and existing distribution archives.

### Affected Files

- `doc/design/usb-display-icon-ipad-iphone-v8.svg`
- `doc/design/usb-display-icon-ipad-iphone-v8-vector-preview.png`
- All ten PNG files in `USBDisplay/Resources/Assets.xcassets/AppIcon.appiconset/`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- Regenerated assets with the existing Swift/AppKit export script. Verified all ten declared dimensions, fully opaque alpha, and pure-white background samples. Compared the SVG device group with HEAD and confirmed it is unchanged.
- Visually inspected the rendered white-background artwork. A dedicated native-app inspection confirmed the exact Debug bundle's small header icon and large Preview in Finder both show the white background, dark device outlines, and pale-blue screens, without the old blue background.
- The Debug build passed on Xcode 27.2. The canonical `./script/build_and_run.sh --verify` stopped at sandboxed LaunchServices with `kLSNoExecutableErr` after the successful build. Reopening the same bundle outside the sandbox succeeded; a subsequent process check confirmed the canonical Debug app running. Build log: `/tmp/USBDisplay-white-icon-build.log`.
- Strict deep Debug signature verification passed. Native AppKit rendering of the compiled `AppIcon.icns` at 16 and 32 pixels showed white backgrounds. `iconutil` extracted four legacy representations: 32-, 128-, and 256-pixel images matched the source pixels exactly, while its 16-pixel PNG had 34 incorrect blue-channel values near the bottom. The native 16-pixel rendering and Finder inspection did not show that export discrepancy. Git whitespace checks passed.
- Application unit tests, a new Release build, distribution packaging, and physical capture validation: Not run for this asset-only change.

### Remaining Risks or Follow-up Work

- Existing DMG and ZIP packages retain the blue icon and need regeneration when a new package is requested.
- Older macOS icon presentation and distribution acceptance remain unverified.


## 2026-11-13 — Center and Align the Devices in a Native Layered App Icon

### Summary

- Replace the shipping flat artwork with a native `AppIcon.icon` document. Use six 1024-pixel SVG layers in four depth groups, with a white default background, blue-gray enclosures, and pale-blue screens.
- Optically center the device pair and align both enclosure bottoms at `y = 816`. Preserve the foreground iPhone overlap, Dynamic Island, and both home indicators.
- Let Icon Composer apply the system mask, glass highlights, lighting, shadows, and appearance adaptation. Set group translucency to 15% and disable glass on the small screen details for legibility. No material effects or masks are baked into the SVG artwork.
- Add the `.icon` source to the Xcode resource phase with the native file type. Keep `AppIcon` selected in both configurations; Xcode compiles native layers and produces compatibility images for older deployment targets. Preserve the earlier flat source/catalog as historical artwork and label its generator accordingly.
- Add a preview-export script and design notes grounded in the installed Xcode 27.2 documentation, current Apple Icon Composer/HIG documentation, and Apple's Icon Composer session.

### Affected Files

- `USBDisplay/Resources/AppIcon.icon/icon.json`
- Six SVG files in `USBDisplay/Resources/AppIcon.icon/Assets/`
- `USBDisplay.xcodeproj/project.pbxproj`
- `script/export_app_icon.sh`
- `script/generate_app_icon.swift`
- `doc/design/icon-composer.md`
- `doc/design/usb-display-icon-composer-preview.png`
- `doc/current.md`
- `doc/devlog.md`

### Validation

- `./script/build_and_run.sh --verify` passed, including Debug build, relaunch, and process verification. Log: `/tmp/USBDisplay-icon-composer-debug.log`.
- Release build passed for arm64 and retained minimum macOS 14.0. Log: `/tmp/USBDisplay-icon-composer-release.log`. The expected no-AppIntents metadata-extraction notice was the only Release warning.
- Debug and Release bundles passed strict deep signature verification and contain the expected `AppIcon` metadata. Asset catalog inspection confirmed six compiled vectors, four native groups for each of default/dark/tintable appearances, three image stacks, and compatibility icon images.
- All six generation-27 appearance previews and a generation-26 default preview exported at 1024 by 1024 pixels with Apple's Icon Composer 27.2 renderer. Inspected default, dark, clear-light, tinted-dark, and generation-26 images. SVG checks confirmed the shared baseline, common canvas, four groups/six layers, and absence of baked effects or an outer mask.
- Dedicated native inspection of the exact `.icon` document confirmed a centered white-default icon, aligned enclosure bottoms, glass highlights/shadows, crisp screen details, and readable dark/mono variants. The UI reported six layers in four groups and design generation 27; no manual document edits were needed.
- The generated compatibility `AppIcon.icns` visibly contains the new aligned dimensional artwork. Finder initially retained the previous flat icon and stale bundle metadata. After touching and re-registering only the Debug bundle with LaunchServices, Finder's header and large Preview both showed the new icon and updated metadata. No global cache clearing or Finder/Dock restart was performed.
- Initial sandboxed `ictool` attempts returned a misleading file-open error; native rendering succeeded outside the sandbox. Computer Use could not initially launch Icon Composer and timed out; launching the document with LaunchServices outside the sandbox enabled successful native inspection.
- Project plist validation, shell syntax, and Git whitespace checks passed. Application unit tests, physical capture tests, older-system runtime acceptance, Intel Release build, and distribution packaging: Not run for this icon-only change.

### Remaining Risks or Follow-up Work

- Existing DMG and ZIP archives still contain the earlier blue flat icon. Regenerate them when a new package is requested.
- macOS 14/15 runtime presentation and distribution acceptance remain unverified. Generation-26 and generation-27 renders are previews, not physical runs on every supported OS; native materials can vary by system version.


## 2026-11-13 — Repackage the Local Release with the Layered White Icon

### Summary

- Run the existing local-release packaging workflow against `35e53a7` to include the new centered, bottom-aligned Icon Composer artwork in both DMG and ZIP.
- Preserve version 0.3.0 (build 3), the macOS 14 minimum, Apple Silicon/Intel executables, hardened runtime, and local ad-hoc signing. Keep the previous packages in their original directory.
- Save the new archives, checksums, signature/entitlement records, a resource comparison report, and an extracted icon preview in `.build/Distribution/USBDisplay-0.3.0-build3-local.1OmvAr/`.

### Affected Files

- `doc/current.md`
- `doc/devlog.md`
- Ignored `.build/Distribution/USBDisplay-0.3.0-build3-local.1OmvAr/` artifacts; application sources and packaging scripts are unchanged.

### Validation

- `./script/package_local_release.sh` passed on Xcode 27.2, including the universal Release build, strict deep signatures on the source app, mounted DMG app and extracted ZIP app, and DMG integrity. Log: `/tmp/USBDisplay-layered-icon-package.log`.
- Verified the executable contains `x86_64` and `arm64`, the app requires macOS 14.0, and the only entitlement is `com.apple.security.device.camera = true`.
- Read-only mounted the final DMG and read the ZIP directly. Both archives' `AppIcon.icns`, `Assets.car`, executable, and Info.plist match the rebuilt source app byte for byte. ZIP CRC validation and both saved SHA-256 checks passed. The DMG retains its Applications shortcut.
- Asset inspection confirmed all six icon vectors, four depth groups in each of three appearances, and three native image stacks. The extracted compatibility icon visibly shows the new white background and aligned dimensional devices. Details are saved in `icon-validation.json` beside the packages.
- Final DMG size: 2,281,016 bytes. Final ZIP size: 2,144,470 bytes. SHA-256: DMG `71fbdd35eb989bfd70dfdff3320a72a126f193a1f2ab2bd47b9e1e92d359071f`; ZIP `086cca74cf4eb1cac02fc2bef5d538395dd6be581c6308f247434ad9d8a06054`.
- Gatekeeper execution assessment returned `rejected` (exit 3), consistent with ad-hoc signing and no notarization. The build emitted the expected no-AppIntents notice; successful image mount/detach operations emitted host deprecation notices.
- Git whitespace checks passed. Application tests, packaged-Release launch, physical capture, older macOS runtime checks, and installation into Applications: Not run for this repackaging task.

### Remaining Risks or Follow-up Work

- These remain local evaluation packages without Developer ID signing or Apple notarization. Public-distribution trust and broader runtime acceptance remain outstanding.


## 2026-11-13 — Remove Historical Builds and Make Test Artifacts Temporary

### Summary

- Remove 18 historical Xcode build/validation directories and the obsolete SwiftPM architecture tree, module cache, database, manifests, empty dependency directories, lock file, and Debug/Release symlinks at the user's request. Preserve `.build/Xcode`, `.build/Distribution`, and the existing icon artwork/previews.
- Reduce allocated `.build` usage from 4,390,792 KiB to 802,596 KiB (about 4.19 GiB to 784 MiB), reclaiming about 3.42 GiB. The retained Xcode tree occupies 725,328 KiB and Distribution occupies 5,976 KiB.
- Add `script/test.sh` as the canonical macOS test entrypoint. Each run owns a unique temporary directory, disables indexing, builds a Debug test host without hardened runtime, and deletes its caches and test results on success, failure, or HUP/INT/TERM interruption. Interrupted runs terminate and wait for their Xcode process before cleanup; the script preserves the test or signal exit status.
- Support explicit test inclusion/exclusion filters without accepting build-path overrides. Keep console output available and document that detailed result bundles are temporary.
- Record the temporary-artifact policy in the project collaboration instructions so later test and validation tasks do not recreate persistent per-task caches.

### Affected Files

- `script/test.sh`
- `AGENTS.md`
- `doc/current.md`
- `doc/devlog.md`
- Removed ignored historical build directories and SwiftPM artifacts under `.build/`; application code and release packages are unchanged.

### Validation

- Checked active build/app executable paths before cleanup; no matching build or app process was running.
- Compared a SHA-256/file-type/symlink manifest of all 6,735 entries in `.build/Xcode` and `.build/Distribution` before cleanup and after the real test run. Both retained trees are unchanged.
- Ran `./script/test.sh` successfully with Xcode 27.2: all 105 Debug tests in 14 suites passed, with no failed test cases. Xcode emitted its expected no-AppIntents metadata-extraction notices. The script exited with status 0, removed its real temporary build/result directory, and left no `TestRun.*` directories.
- Used an isolated fake-Xcode fixture with paths containing spaces to verify success cleanup, failure status 65 propagation, HUP/INT/TERM exit statuses and child shutdown before deletion, simultaneous-run isolation, test-filter forwarding, help behavior, and rejection of path overrides and empty filters. Persistent-directory and unrelated-run sentinels remained intact; no fixture artifacts were retained.
- Bash syntax and Git whitespace checks passed. No app sources changed. Release rebuild, packaging, physical-device capture, and older-macOS runtime checks: Not run for this tooling-only change.

### Remaining Risks or Follow-up Work

- Each test invocation rebuilds from scratch, trading incremental build speed and retained detailed result bundles for disk space. Console output can be redirected explicitly when diagnostics need to be saved.
- SIGKILL, a shell crash, or power loss can prevent exit traps. Any abandoned run directory needs manual cleanup after confirming that it is inactive. Direct Xcode UI tests and commands that bypass `script/test.sh` do not get this script's cleanup behavior.


## 2026-11-13 — Prepare the First Open-source Release

### Summary

- Prepare version 1.0.0 (build 4) as the first GitHub release, retaining the existing app behavior, bundle identifier, macOS 14 deployment target, and source-layer structure.
- Add the user-selected MIT license and include it in the built app alongside third-party notices. Add a public README with versioned DMG/ZIP/checksum links, installation/troubleshooting guidance, contribution instructions, changelog, release procedure, roadmap, issue forms, PR template, and CODEOWNERS.
- Add `--github` to the packaging command for stable universal-archive filenames. Preserve the no-argument local naming and existing ad-hoc signing. Include accurate signing and runtime limitations in the package notes and public documentation.
- Create the USB Display project in the user-selected Question King Linear workspace. Add 12 backlog issues (QUE-20–QUE-31), each with source context and acceptance criteria. Separate the observed startup/black-preview issue from validation gaps and proposed features. Keep the already fixed F1–F9 audit findings closed in the historical record. Do not schedule or implement future release scope.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`, `script/package_local_release.sh`, and `LICENSE`
- `README.md`, `CONTRIBUTING.md`, and `CHANGELOG.md`
- `.github/CODEOWNERS`, `.github/pull_request_template.md`, and `.github/ISSUE_TEMPLATE/`
- `doc/installation.md`, `doc/roadmap.md`, `doc/releases.md`, and `doc/releases/v1.0.0.md`
- `doc/current.md` and `doc/devlog.md`
- Ignored release assets in `.build/Distribution/USBDisplay-1.0.0-macOS-universal.gUKiYU/`
- External Linear project and backlog: https://linear.app/question-king/project/usb-display-954f744f1c76

### Validation

- `./script/test.sh` passed all 105 Debug tests in 14 suites, with no failures, and removed the temporary Xcode directory. All nine Python catalog tests and offline catalog verification passed.
- `./script/package_local_release.sh --github` passed the universal Release build, strict deep source/mounted-DMG/extracted-ZIP signature checks, and DMG integrity. ZIP CRC, both package SHA-256 hashes, arm64/x86_64 slices, version 1.0.0, build 4, minimum macOS 14.0, bundled license/notices, and matching ZIP app resources were verified. The sole entitlement is `com.apple.security.device.camera`.
- DMG SHA-256: `30201b92fb537d6d03d39e5e44c5c7c16a3816381169defb81725820d8c5badc`. ZIP SHA-256: `6aab4e2defba0ca365cb81fbd4825e489d8c08545701ce0a73ace5cae57aa1c7`.
- Gatekeeper rejected the actual 1.0.0 bundle with exit 3. The installed identities include Apple Development/Distribution, but no Developer ID Application identity. No signing credential was created or uploaded, and no notarization was claimed.
- Shell syntax, Xcode project plist, new documentation relative links, issue-template YAML, and Git whitespace checks passed. A focused pre-publication pattern check of 402 historical Git blobs found no matching private keys or common GitHub/OpenAI/AWS credential forms; this is not an exhaustive security audit.
- Xcode emitted expected no-AppIntents metadata notices; the successful disk-image operations emitted host deprecation notices.
- Packaged-Release launch, physical capture, older-system/Intel runtime, and new performance checks: Not run. GitHub publication and public download verification are recorded separately after completion.

### Remaining Risks or Follow-up Work

- The initial downloads are ad-hoc signed and not notarized; macOS may block first launch. Signing/notarization, runtime coverage, capture startup, interaction/performance evidence, and automation are tracked in the linked backlog.
- There is no hosted CI, built-in updater, or automatic GitHub/Linear issue synchronization. Future release scope and dates remain undecided.


## 2026-11-13 — Upload and Verify the Private 1.0.0 Release Draft

### Summary

- Push the reviewed source and documentation at `30b39a195d525d73792024906e4376f04f7689db` and its annotated `v1.0.0` tag to the existing GitHub repository without rewriting history.
- Create a private release draft titled USB Display 1.0.0 with versioned notes, the universal DMG/ZIP, and `SHA256SUMS.txt`.
- Automatic approval review rejected the attempt to change the private repository to public because it would disclose the entire source and Git history without sufficiently explicit visibility authorization. Request confirmation for that precise scope. Keep the repository private and the release unpublished while that confirmation is pending.

### Affected Files

- `doc/current.md` and `doc/devlog.md`
- Remote `main`, annotated `v1.0.0`, and the GitHub release draft at https://github.com/BoboX-NPU/USBDisplay/releases/tag/untagged-b210819664ef70364c0c

### Validation

- Verified all three draft assets are uploaded: DMG 2,280,843 bytes, ZIP 2,145,380 bytes, checksums 206 bytes. Downloaded the authenticated draft assets into an isolated temporary directory and matched both SHA-256 hashes and the checksum file against the local packages. Removed the temporary downloads.
- Verified the remote annotated tag resolves to the exact release-source commit. Confirmed all 12 Linear tasks exist in the USB Display project with Backlog status and the intended labels/priorities.
- Git whitespace check passed. New builds/tests: Not run for this documentation-only publication-status record; the immediately preceding release-validation results remain applicable.

### Remaining Risks or Follow-up Work

- Confirm public visibility for the complete repository/history, then publish the draft and verify unauthenticated source/download access. The versioned public download links are not live while the repository/release remain private/draft.
- Signing/notarization and physical-runtime limitations remain unchanged.


## 2026-11-13 — Publish USB Display 1.0.0 Publicly

### Summary

- After the maintainer explicitly authorized public visibility for the complete repository and all existing Git history, make `BoboX-NPU/USBDisplay` public. Set the project description, release homepage, and relevant repository topics.
- Publish the already verified 1.0.0 draft and mark it as the latest non-prerelease release at https://github.com/BoboX-NPU/USBDisplay/releases/tag/v1.0.0. GitHub reports publication at 22:12:38 UTC on 2026-11-13.
- Preserve the existing release assets and annotated tag at `30b39a195d525d73792024906e4376f04f7689db`. Update current state to replace the pending-approval/draft status with verified public availability.

### Affected Files

- `doc/current.md` and `doc/devlog.md`
- GitHub repository visibility, description, homepage, topics, and 1.0.0 release publication/latest status

### Validation

- Unauthenticated GitHub API requests confirmed public visibility, the MIT license, latest tag `v1.0.0`, `draft=false`, and `prerelease=false`.
- Downloaded all three release assets without authentication into an isolated temporary directory. The checksum file matched the local file byte for byte. DMG SHA-256 remained `30201b92fb537d6d03d39e5e44c5c7c16a3816381169defb81725820d8c5badc`; ZIP SHA-256 remained `6aab4e2defba0ca365cb81fbd4825e489d8c08545701ce0a73ace5cae57aa1c7`. Removed the temporary downloads after verification.
- Verified unauthenticated access to the repository, release, and README pages. Verified the public annotated tag still resolves to the validated release-source commit.
- Git whitespace checks passed. New builds and tests: Not run for this publication/documentation-only step; the previously recorded 105 application tests, nine catalog tests, and universal-package validation remain applicable.

### Remaining Risks or Follow-up Work

- Downloads remain ad-hoc signed and not notarized; publishing does not change Gatekeeper trust. Signing and the existing runtime/interaction/performance limits remain tracked in Linear.
- No new feature work, hosted CI, automatic updater, or issue synchronization was introduced. The maintainer will define the next release separately.


## 2026-11-13 — Sign and Notarize the 1.0.1 Distribution App

### Summary

- Prepare version 1.0.1 (build 5) for the distribution-trust correction while preserving the published 1.0.0 source tag and downloads. Application capture/window source code is unchanged.
- After explicit user confirmation for Developer ID credential creation, inspect Xcode's paid-team account and attempt certificate creation once. Xcode did not show a new certificate or error, so no repeated manual issuance/revocation was attempted. Use Xcode's automatic Developer ID export with the existing authenticated account; upload succeeded, and notarized export returned a Developer ID-signed app with a stapled Apple ticket.
- The signing authority is `Developer ID Application: mingbo xue (9PSN33WBG7)`, certificate SHA-1 `CFBE77C410EBBDBC13DD2C63892651A6B0EFA160`. The local identity inventory still lists only the existing development/distribution identities; no claim is made that a new Developer ID private key was installed locally. No app-specific password or private API key was supplied, committed, or exported.
- Add `--notarized-app` packaging for a pre-verified signed/stapled app. Preserve the existing local ad-hoc modes. Validate trust before output creation and on the mounted-DMG/extracted-ZIP copies, without rebuilding or changing the supplied app.
- Provide matching Simplified Chinese and English README sections and bilingual package installation notes. Record the user's explicit README exception to the project's English-only Markdown convention. Update installation, changelog, release, and notarization documentation.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`, `script/package_local_release.sh`
- `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, and `CHANGELOG.md`
- `doc/installation.md`, `doc/notarization.md`, `doc/releases.md`, and `doc/releases/v1.0.1.md`
- `doc/current.md` and `doc/devlog.md`
- Ignored artifacts in `.build/Distribution/USBDisplay-1.0.1-macOS-universal.GzgBxe/`

### Validation

- The universal Release archive built on Xcode 27.2. Automatic `developer-id` export with `destination=upload` and team `9PSN33WBG7` succeeded; `-exportNotarizedApp` succeeded. Xcode distribution identifier: `684ADD00-E29D-426B-8515-83316CC0BEAE`. This is an Xcode distribution identifier, not asserted to be the notarytool submission ID.
- The exported app reports Developer ID authority, a secure timestamp, hardened runtime, the expected team, version 1.0.1/build 5, and both CPU architectures. The sole entitlement is `com.apple.security.device.camera`.
- Strict signature and stapled-ticket checks passed on the exported app, mounted-DMG app, and extracted-ZIP app. All three Gatekeeper checks returned `accepted` and `source=Notarized Developer ID`.
- An extracted temporary app with a download quarantine marker passed strict signatures, ticket validation, Gatekeeper, and `syspolicy_check distribution` (all exit 0). App metadata, executable, icon resources, MIT license, and third-party notices matched the notarized export. This is a policy/distribution check, not a new physical capture or GUI-launch acceptance run.
- DMG integrity and package SHA-256 checks passed. DMG SHA-256: `4ea066c2167fb781b02efebaf106c05c3113f57e5d4de6fbd4ded3b997a1b23c`. ZIP SHA-256: `4acaebc43c5f5582fdf94f741e5717a1f8dc4f7804f44645a9f861d043cff572`.
- The new packaging mode rejected the existing ad-hoc app with exit 3 before creating a package directory. An initial inline-requirement command syntax error was corrected before the successful packaging run.
- The first full Debug run had 103 passes and two failures in `WindowLayoutIntegrationTests.emptyFullScreenRoundTripRestoresOrdinarySizeIncludingDeviceArrival` and `fullScreenRestoresOrdinaryGeometryAndSidebarState`. The isolated window integration suite then passed all 11 tests, and a subsequent full run passed all 105 tests without changing runtime or test sources. All temporary test build directories were removed. The inconsistent result is recorded on Linear QUE-24; its cause remains unisolated.
- All nine Python catalog tests and offline catalog verification passed. Shell syntax, Xcode project plist, bilingual README section/version parity, documentation relative links, and Git whitespace checks passed. Older-system/Intel runtime and new physical-device checks: Not run.

### Remaining Risks or Follow-up Work

- Publish and verify the new 1.0.1 downloads, then close the signing/notarization task in Linear. Keep concise verification records and remove this task's temporary archive, exports, and logs.
- The notarization ticket belongs to the embedded app; no independent notarization of the DMG container is claimed. Normal Internet-download confirmation and Camera permission prompts can remain.
- The existing capture-startup, compatibility, interaction/performance, and CI backlog remains separate from distribution trust. Investigate the intermittent full-screen test failures recorded in QUE-24; the passing reruns do not establish their cause.


## 2026-11-13 — Publish and Verify the Notarized 1.0.1 Downloads

### Summary

- Publish the reviewed `1441504a781c78f7364f3dc769871d905d3bc50d` source and annotated `v1.0.1` tag, then publish the verified DMG, ZIP, and checksums as the latest non-prerelease release. GitHub publication time is 22:30:33 UTC on 2026-11-13.
- Verify both public downloads and the bilingual README without authentication. Preserve the 1.0.0 source tag and asset hashes.
- Mark Linear QUE-22 Done with the signing/notarization evidence and release link. Move the completed topic out of the public roadmap's backlog; leave 11 follow-ups unscheduled. Record the intermittent integration-test observation separately on QUE-24.
- Remove the task's temporary archive, exported app, diagnostic wrapper, Xcode distribution log bundle, and validation logs after saving concise verification records beside the release packages. No temporary test build directories remain.

### Affected Files

- `doc/current.md`, `doc/roadmap.md`, and `doc/devlog.md`
- GitHub `main`, annotated `v1.0.1`, and https://github.com/BoboX-NPU/USBDisplay/releases/tag/v1.0.1
- Linear QUE-22 and QUE-24
- Ignored `public-download-verification.json` beside the 1.0.1 release assets

### Validation

- GitHub's uploaded asset digests matched local files before publication. Anonymous downloads of all three published assets then matched local bytes and checksums. DMG size: 1,847,295 bytes. ZIP size: 1,790,903 bytes. Checksum file: 206 bytes.
- Apps extracted from the downloaded ZIP and copied from the read-only-mounted downloaded DMG were independently marked with download quarantine. Both passed strict signature checks, `stapler validate`, Gatekeeper (`accepted / Notarized Developer ID`), and `syspolicy_check distribution`, with all commands exiting 0. Both retained version 1.0.1/build 5, arm64/x86_64, hardened runtime, the expected Developer ID authority, and the stapled ticket.
- The downloaded DMG includes its Applications shortcut and bilingual Read Me. The public repository README contains both complete language sections, language links, and 1.0.1 download links. The public annotated tag resolves to the exact reviewed release source; 1.0.0 DMG/ZIP digests remain unchanged.
- The final 105-test application run, 11-test focused window run, nine catalog tests, and the initial two intermittent failures are recorded in the preceding entry. Additional builds/tests for this documentation-only publication record: Not run. Git whitespace checks passed.

### Remaining Risks or Follow-up Work

- The app is notarized; the DMG is a transport container without a separately claimed notarization ticket. First-launch Internet confirmation and Camera permission prompts remain normal.
- Existing runtime/compatibility/performance work and the intermittent full-screen test investigation remain in the backlog. No built-in updater or hosted CI was added.


## 2026-11-13 — Design the 1.0.2 Drag-to-Install Window

### Summary

- Replace the ordinary folder-like DMG presentation with a white/blue-gray branded installer: native app/Applications icons, a directional arrow, bilingual installation/next-step guidance, and a saved initial Finder icon view.
- Add native AppKit artwork generation and standard/Retina PNG assets. Use a 720-by-460-point graphic, 112-point icons, and a 720-by-552-point initial window that accommodates host Finder bars without changing global preferences.
- Add exact wheel versions/hashes for release-only `dmgbuild`, `ds-store`, and `mac-alias` tooling. Packaging installs them in a temporary environment by default or accepts a prepared `DMGBUILD_PYTHON`; cleanup removes tools/staging and newly created incomplete output on failure. Python dependencies are not shipped in the app.
- Keep only the app and Applications shortcut visible. The DMG background carries concise bilingual instructions; detailed text notes remain beside local archives and in public documentation.
- Prepare version 1.0.2 (build 6), retaining application/test sources and older published downloads. Archive and export through the existing Developer ID/notarization workflow before styled packaging.

### Affected Files

- `Packaging/DMG/background.png` and `background@2x.png`
- `script/generate_dmg_background.swift`, `script/dmg_settings.py`, `script/requirements-dmg.txt`, and `script/package_local_release.sh`
- `USBDisplay.xcodeproj/project.pbxproj`
- `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `doc/current.md`, and `doc/devlog.md`
- `doc/design/dmg-installer.md`, `doc/releases.md`, and `doc/releases/v1.0.2.md`
- Ignored release artifacts in `.build/Distribution/USBDisplay-1.0.2-macOS-universal.CtDy4I/`

### Validation

- Native Finder inspection confirmed the original ordinary presentation. The first custom preview exposed a duplicate Retina transform; after correction, both image scales render the same logical composition. The corrected preview showed complete bilingual text/footer, native icons centered on their backings and aligned with the arrow, readable labels, and no overlap, clipping, scrollbars, or unintended empty panel. Toolbar/sidebar were hidden; the host's tab/path/status preferences remained visible.
- A separate final-DMG GUI check stopped when CUA detected user activity, before opening the final image. No final-image GUI acceptance is claimed. The final package uses the inspected artwork/positions; the native icon-extension override was removed afterward to preserve signing integrity.
- The preview's extension-hiding option added FinderInfo to the signed app and caused strict signature verification to fail. Disable that mutation. The final DMG app then passed strict signatures, stapled-ticket validation, and Gatekeeper (`accepted / Notarized Developer ID`), as did the source and extracted ZIP app.
- The universal archive, Developer ID upload, notarized export, fresh hash-pinned tool installation, DMG integrity, package checksums, and a complete app file-content comparison against the notarized export passed. Saved metadata specifies icon view, 112-point icons at `(200,226)` and `(520,226)`, background-image type, requested hidden toolbar/sidebar, and window bounds `{{180,140},{720,552}}`. The only visible items are `USB Display.app` and the `/Applications` shortcut.
- DMG SHA-256: `147c8e70ae8974420d6f232331790a83f2a19016d4863c3bfa86ea76ddd50765`. ZIP SHA-256: `11dc0ed86b090a7be18e85ac5a28c91610443959c43c8866942f91689126ea69`.
- An intentionally failing packaging-tool override removed the newly created incomplete output while preserving all previous package directories. Task test directories were also cleaned automatically.
- The full Debug suite had 103 passes and the same two previously recorded full-screen integration failures. The isolated window integration suite passed all 11 tests. Application/test sources are unchanged from 1.0.1. Update QUE-24 with this repeated observation; no full-suite pass is claimed for this run. All nine catalog tests and offline resource verification passed.
- Authored text/arrow contrast passed the documented thresholds; image dimensions/DPI, Swift-format lint for the renderer, shell/project syntax, and Git whitespace checks passed. New physical capture and older-OS runtime checks: Not run.

### Remaining Risks or Follow-up Work

- Publish and verify the styled 1.0.2 downloads. Preserve the exact notarized app; Finder metadata and artwork belong outside its bundle.
- Finder can preserve user view preferences. Older Finder/macOS appearance and broader accessibility coverage remain unverified.
- The existing runtime/compatibility/performance backlog and intermittent full-screen integration failures remain separate from installer styling.


## 2026-11-13 — Publish and Verify the Styled 1.0.2 Installer

### Summary

- Publish the reviewed `956c7670d943c6d468b4b020c3a9d64d64056e3e` source, annotated `v1.0.2` tag, styled DMG, ZIP, and checksums. GitHub reports publication at 22:53:17 UTC on 2026-11-13; 1.0.2 is the latest non-prerelease release.
- Verify the actual public downloads and saved Finder artwork/layout without relying on the local preview files. Preserve the 1.0.1 assets unchanged.
- Eject only the two task-created preview images and remove temporary Python tools, Swift module cache, source/export/archive copies, diagnostic logs, and the Xcode distribution log bundle. Preserve the user's pre-existing `/Volumes/USB Display` mount and all release packages. No temporary test directories remain.

### Affected Files

- `doc/current.md` and `doc/devlog.md`
- Remote `main`, `v1.0.2`, and https://github.com/BoboX-NPU/USBDisplay/releases/tag/v1.0.2
- Ignored `public-download-verification.json` beside the 1.0.2 release packages

### Validation

- GitHub asset digests matched local files before publication. Anonymous downloads of the DMG, ZIP, and checksum file matched local bytes and hashes after publication. DMG size: 2,518,681 bytes. ZIP size: 1,790,889 bytes. Checksum file: 206 bytes.
- The downloaded DMG contains exactly two visible items, a correct Applications shortcut, icon-view metadata with the intended bounds/positions, and both standard/Retina background representations. The metadata/data checks passed; final-image native GUI inspection remains limited as recorded in the preceding entry.
- Apps copied from the downloaded DMG and extracted from the downloaded ZIP were marked with download quarantine. Both passed strict code signatures, stapled-ticket validation, Gatekeeper (`accepted / Notarized Developer ID`), and `syspolicy_check distribution`. Version/build remained 1.0.2/6, and the camera entitlement is the only entitlement.
- The public annotated tag resolves to the reviewed release source, and 1.0.1 DMG/ZIP digests remain unchanged.
- Git whitespace checks passed. Additional builds/tests for this documentation-only publication record: Not run. The 103/105 full-suite result, 11/11 isolated window result, and nine passing catalog checks remain explicitly recorded above.

### Remaining Risks or Follow-up Work

- The known two full-screen integration failures remain tracked on QUE-24; this installer redesign does not fix or conceal them.
- Finder may retain user-specific tab/path/status preferences. Older Finder/appearance coverage and a final-image native GUI recheck remain unverified; the corrected preview passed native visual inspection and the final package's matching layout data passed verification.


## 2026-11-13 — Simplify the Installer to a White Arc Preview

### Summary

- Apply the maintainer's latest direction: plain white background, one flat circular-arc arrow from the app toward Applications, and only `Connect your iPhone or iPad via USB.` at the bottom. Remove the previous heading, extra copy, circles, divider, background color, and dimensional arrow treatments.
- Use a compact 640-by-360-point canvas with native 112-point icons at `(180,158)` and `(460,158)`, inside a 640-by-452-point initial Finder window. Raise the footer to clear the observed path-bar divider.
- Use English for the fixed background image, as requested when runtime system-language selection is unavailable in this static-image workflow. The repository README remains bilingual.
- Build a local preview containing the exact already-notarized 1.0.2 app. Do not bump the app version, replace published files, or create a GitHub release during this visual iteration. Retain the final preview in `.build/Distribution/USBDisplay-minimal-installer-preview.41qf2yqo/USBDisplay-arc-installer-preview.dmg`.

### Affected Files

- `script/generate_dmg_background.swift` and `script/dmg_settings.py`
- `Packaging/DMG/background.png` and `background@2x.png`
- `CHANGELOG.md`, `doc/design/dmg-installer.md`, `doc/current.md`, and `doc/devlog.md`
- Ignored local preview DMG and its checksum file

### Validation

- Native artwork generation and strict Swift-format lint passed. Standard/Retina images have the expected 640-by-360 and 1280-by-720 sizes; sampled background regions are fully opaque pure white.
- The final preview passed DMG integrity, saved-layout, complete app-file comparison, strict code-signature, stapled-ticket, and Gatekeeper checks. Gatekeeper reports `Notarized Developer ID`; the app is unchanged from the 1.0.2 signed payload.
- The first compact footer position touched the Finder path-bar divider; raising it resolved the observed clearance problem. Earlier navigation attempts did not show the revised arrow. Final native inspection opened the exact `USB Display Arc Preview` volume and confirmed a flat gray circular arc, two correctly placed icons, fully visible English footer, and no extra background text, frames, overlap, or clipping. Leave this final preview frontmost for review.
- Remove obsolete task preview volumes/files and temporary Python tools, Swift module cache, source copies, and logs. Preserve the final preview and the user's existing published-release mounts.
- Git whitespace checks passed. Application build/unit tests: Not run for this artwork/layout-only iteration; application and test sources and published releases are unchanged.

### Remaining Risks or Follow-up Work

- The revised artwork is a local preview awaiting the maintainer's visual feedback. Public 1.0.2 downloads still contain their original released artwork.
- Native Finder filenames/bars remain system-owned, and older-OS/appearance coverage remains unverified. Existing app-runtime and test-instability follow-ups are unchanged.


## 2026-11-13 — Prepare the Approved Minimal Installer as 1.0.3

### Summary

- Accept the maintainer-approved pure-white, flat circular-arc installer and English USB connection footer for publication. Preserve the exact approved background and icon-layout file hashes.
- Set version 1.0.3 (build 7), create a universal Release archive, and sign/notarize through the existing authenticated Xcode Developer ID workflow. Application and test sources remain unchanged.
- Package the signed/stapled app in `.build/Distribution/USBDisplay-1.0.3-macOS-universal.fr2GIE/`. Update both README language sections to the new DMG, ZIP, and checksum URLs, and add versioned release notes without replacing older releases.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`, `README.md`, and `CHANGELOG.md`
- `doc/current.md`, `doc/design/dmg-installer.md`, `doc/releases.md`, `doc/releases/v1.0.3.md`, and `doc/devlog.md`
- Ignored 1.0.3 release packages and temporary archive/validation files
- Linear QUE-24 assertion evidence

### Validation

- Universal Release archive, Developer ID upload, notarized export, and packaging passed. Source, mounted-DMG, and extracted-ZIP apps passed strict code signatures, stapled-ticket validation, and Gatekeeper (`accepted / Notarized Developer ID`). Version/build is 1.0.3/7, minimum macOS is 14.0, and the only entitlement is camera access. Hardened runtime and the expected Developer ID authority are present.
- Both packaged TIFF image representations match the approved standard/Retina PNGs pixel for pixel. The approved background and layout source files are unchanged. The disk root contains only the app and the correct Applications shortcut as visible items.
- ZIP CRC/content, DMG integrity, package SHA-256, project/shell syntax, and Git whitespace checks passed. DMG SHA-256: `9871b3257cd89c6c1e8a2505e4ea37db7d5a8df6e857ece39d3cbde18181b2c0`. ZIP SHA-256: `18ad4b1abfff016cb35a509dbda428f0b9a80ef7b161f1de5ee4ed073f3309bd`.
- Full Debug result: 103 passed, two known full-screen integration failures. The isolated window suite passed all 11 tests. A temporary diagnostic wrapper captured xcresult assertion summaries before normal cleanup: both failures preserve size but change window origins from `(1917,-346)` to `(792,47)` and `(2138,-346)` to `(1288,47)`. Record this on QUE-24 for investigation of display-context/screen-fitting fixture assumptions; the cause is not claimed fixed or conclusively isolated.
- All nine catalog tests and offline resource verification passed. Test build directories were removed. No new native GUI, physical capture, or older-OS/Intel runtime acceptance was run; the approved preview's visual checks remain applicable to unchanged artwork/layout.

### Remaining Risks or Follow-up Work

- Publish and verify the actual 1.0.3 downloads and README links, then clean this task's temporary archive/tooling/logs.
- The two full-screen integration failures and existing runtime/compatibility/performance follow-ups remain open. The app is notarized; no separate DMG-container notarization is claimed.


## 2026-11-13 — Publish the Approved 1.0.3 Installer and README Links

### Summary

- Publish the approved minimal installer as the latest non-prerelease 1.0.3 release, with source tag `c6926fa4e28e7971142028388a8c348b2e42bd5b`. GitHub reports publication at 23:30:02 UTC on 2026-11-13.
- Publish the accepted artwork revision and update all six download links across the README's Chinese and English sections. Preserve the earlier release files.
- Remove this task's temporary archive, exports, diagnostic wrapper, raw test/notarization logs, and Xcode distribution log bundle. Keep final release packages and concise verification results; preserve the user's existing preview and mounted volumes.

### Affected Files

- `doc/current.md` and `doc/devlog.md`
- Remote `main`, `v1.0.3`, and https://github.com/BoboX-NPU/USBDisplay/releases/tag/v1.0.3
- Ignored `public-download-verification.json` beside the 1.0.3 release packages

### Validation

- Draft asset digests matched local files before publication. Anonymous downloads of the final DMG, ZIP, and checksum file matched local bytes/hashes afterward. DMG size: 1,911,490 bytes; ZIP size: 1,790,906 bytes; checksum file: 206 bytes.
- The public README exactly matched the local file, and its six download links resolve to the three published asset URLs. The public annotated source tag resolves to the reviewed commit. Previous 1.0.2 DMG/ZIP digests remain unchanged.
- Both downloaded apps, marked with download quarantine, passed strict code-signature checks, stapled-ticket validation, Gatekeeper (`accepted / Notarized Developer ID`), and `syspolicy_check distribution`. Both contain arm64/x86_64, version/build 1.0.3/7, and minimum macOS 14.0.
- Both representations of the downloaded DMG background match the approved PNG pixels exactly. Its only visible installation targets are the app and the correct Applications shortcut.
- Temporary verification downloads and test build directories were cleaned. Git whitespace checks passed. Additional builds/tests for this publication-status-only update: Not run; the 103/105 full-suite, 11/11 focused-suite, and nine passing catalog checks are recorded above.

### Remaining Risks or Follow-up Work

- The two known full-screen integration failures remain tracked on QUE-24 with captured assertion evidence. Runtime/compatibility/performance follow-ups remain separate from this approved installer release.


## 2026-11-14 — Integrate Sparkle Downloads with Explicit Installation

### Summary

- Prepare source version 1.1.0 (build 8), following the project's minor-version policy for new capabilities. Pin Sparkle 2.10.1 through Swift Package Manager and retain its complete license notices. Public downloads remain 1.0.3.
- Add one app-owned updater with daily automatic checks, manual Check for Updates, a persisted automatic-check menu toggle, native download progress, and an explicit Install and Relaunch action. Disable Sparkle's stock silent-update mode and system profiling.
- Automatically start ordinary downloads through a standard-user-driver adapter. Keep major/informational prompts and guard recovered installers. Normal AppKit quit cancels unconfirmed downloads/prepared installations before allowing termination; an accepted install permits Sparkle to terminate and relaunch. Add lifecycle logging and six focused termination-gate tests.
- Generate an app-specific Ed25519 key in the login Keychain, account `com.xuemingbo.iPhoneUSBDisplay.sparkle`, without exporting private key material. Commit only the public key; require signed feeds and pre-extraction archive verification.
- Configure a stable GitHub latest-release appcast asset URL. Add a local preparation script that checks bundle identity, version, architecture, update configuration, signing key, Developer ID team, hardened runtime, signature, stapled ticket, and Gatekeeper, then signs/verifies the ZIP and appcast. Require either an explicit first-release bootstrap or the previous signed feed; refuse output overwrite. No public update feed or release was published.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`, `USBDisplay.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, and `Config/Info.plist`
- `USBDisplay/App/iPhoneUSBDisplayApp.swift`
- `USBDisplay/Services/UpdateController.swift`, `UpdateUserDriver.swift`, and `UpdateInstallationGate.swift`
- `USBDisplay/Views/UpdateCommands.swift` and `USBDisplayTests/UpdateInstallationGateTests.swift`
- `USBDisplay/Resources/ThirdPartyNotices.txt` and `script/prepare_update.py`
- `README.md`, `CHANGELOG.md`, `doc/current.md`, `doc/releases.md`, `doc/updates.md`, `doc/releases/v1.1.0.md`, and this log

### Validation

- Xcode 27.2 resolved the exact Sparkle 2.10.1 revision. Debug build, canonical `./script/build_and_run.sh --verify`, universal Release build, strict bundle signature verification, Swift-format lint, plist/project parsing, shell/Python syntax, and Git whitespace checks passed. Final metadata is 1.1.0/8. Local builds remain ad-hoc signed.
- The first full `./script/test.sh` run passed 111/111. The final full run passed 109/111; a focused updater/window run passed 15/17. Both later runs failed the same pre-existing full-screen test names: `emptyFullScreenRoundTripRestoresOrdinarySizeIncludingDeviceArrival` and `fullScreenRestoresOrdinaryGeometryAndSidebarState`. All six updater tests passed in every run. No window/capture source was changed, and no fix to QUE-24's intermittent tests is claimed. All test build directories and result bundles were removed by the runner.
- A dedicated native-app UI agent used signed localhost update fixtures and isolated identifiers. Automatic check/download reached Ready to Install. A normal quit at that stage logged deferred termination and cancellation, preserving build 8. A subsequent manual check showed increasing download progress; the explicit Install and Relaunch click logged choice 1 and allowed termination, and both disk metadata and About showed build 9. The subsequent check showed the up-to-date alert. Fixture versions 1.0.4/8 and 1.0.5/9 were artificial test versions, never published.
- The first tool-launched fixture changed to build 9 before a recorded install click. Its cause was not conclusively isolated. Native bindings also relaunched/duplicated processes during later state inspection. A fresh fixture launched explicitly with independent lifecycle logs and disk checks stayed on build 8 until the verified consent/cancellation paths above; do not treat the first launch as successful confirmation coverage. Force termination remains outside the normal-quit contract.
- The automatic-check menu entry was observed, but its checkmark was not exposed in the accessibility tree and screenshots were unavailable. Enabled-by-default configuration and a real automatic feed/download request were verified separately.
- Sparkle accepted the signed local feed and rejected modified feed content. The production preparation script rejected the real new ad-hoc universal archive at its Developer ID requirement and wrote no feed, as intended. Successful production-feed generation remains pending a notarized export.
- Developer ID upload/notarization was not run: automatic approval review rejected the Xcode upload because this request authorized Sparkle integration but did not explicitly authorize submitting the application archive to Apple and using signing credentials. No workaround, public release, or new trust claim was made.
- Stopped the localhost fixture server and isolated test processes; removed both test preference/cache domains and the task scratch directory, temporary archives, extracted source, update fixtures, and logs. Preserved canonical `.build/Xcode`, existing `.build/Distribution` packages, and the real signing key.

### Remaining Risks or Follow-up Work

- Obtain authorization for the Apple submission, then Developer ID-sign/notarize the final app and all Sparkle helpers, package it, generate the first signed appcast, and publish/verify a reviewed release. The configured production appcast does not exist until that release is published. Existing users need one manual installation to adopt the updater.
- Validate a real Developer ID-signed upgrade and quarantined public downloads; local ad-hoc fixtures do not prove distribution trust. Keep a secure backup of the update-signing key before migrating the signing Mac.
- The two existing full-screen test failures and prior physical-device/older-OS/Intel validation limits remain open. The initial native-tool launch anomaly was not conclusively isolated; avoid app-binding relaunches during future updater acceptance and retain independent process/version evidence.


## 2026-11-14 — Prepare Notarized 1.1.0 and Verify the Signed Upgrade

### Summary

- Use the maintainer's explicit authorization to sign/notarize 1.1.0 (build 8) with the existing Xcode Developer ID credentials and prepare publication with its signed appcast.
- Fix the release preflight's catalog-reproducibility failure: move the complete Sparkle license from generated `ThirdPartyNotices.txt` into a separate bundled `Sparkle-LICENSE.txt`, restoring deterministic device-data notices without losing updater licensing.
- Archive the universal app, submit it through the existing Xcode workflow, retrieve the notarized export, and package that exact app. Prepare the first signed production appcast with embedded release notes and add it to the checksum file.
- Prepare the bilingual README, changelog, versioned release notes, and current/update documentation for 1.1.0. The public 1.0.3 assets remain untouched.

### Affected Files

- `USBDisplay.xcodeproj/project.pbxproj`, `USBDisplay/Resources/ThirdPartyNotices.txt`, and `USBDisplay/Resources/Sparkle-LICENSE.txt`
- `README.md`, `CHANGELOG.md`, `doc/current.md`, `doc/releases.md`, `doc/releases/v1.1.0.md`, `doc/updates.md`, and this log
- Ignored `.build/Distribution/USBDisplay-1.1.0-macOS-universal.Z1FBwb/` release assets

### Validation

- The initial catalog preflight failed because the previous integration appended a non-generated license to generated notices. After splitting the resource, all nine catalog tests and offline reproducibility verification passed. The notarized bundle contains the complete standalone Sparkle license matching source bytes.
- Universal Release archive, Xcode Developer ID upload, and notarized export passed. Main app, framework, Autoupdate, Updater.app, Downloader.xpc, and Installer.xpc all have the expected Developer ID team `9PSN33WBG7` and pass strict signatures. The app is 1.1.0/8, includes arm64/x86_64, and passes stapled-ticket, Gatekeeper (`Notarized Developer ID`), and `syspolicy_check distribution` checks.
- Both DMG and ZIP packaged-app checks passed without rebuilding or re-signing the notarized export. Production `prepare_update.py --first-release` passed all trust/configuration checks, generated the signed feed, and verified both archive and feed signatures. The checksum file includes both archives and the appcast.
- An unpublished local 1.0.9/build 7 fixture was exported with the existing Developer ID credentials and isolated updater preferences. Its signed localhost feed served the exact notarized production ZIP. Native UI showed Ready to Install while disk metadata remained build 7; the explicit Install and Relaunch click reopened the app and About showed 1.1.0/build 8. Installed file hashes and symlinks exactly match the notarized release payload; its signature, stapled ticket, and Gatekeeper checks passed. This fixture is not a public release and was not separately notarized.
- DMG SHA-256: `5b9e052cef53b5b70c9283d553be3a91e79ed045d79dbee6a6ce9b8189fc89b3`. ZIP SHA-256: `acffdf8df612547aa57ca2b2e73b9712667e8e650725841bfb38e576d36d1958`. Appcast SHA-256: `0a7e2696dcb54558b6bf7a237c1e2c2259bcbebd8b075adea80dc0cef81b991c`.
- Git whitespace and project/plist/shell checks passed. Application tests: Not run again for the license-resource/release-only changes; the immediately preceding 109/111 full result and all six passing updater tests remain applicable to unchanged runtime/test source. The known two full-screen test failures are not fixed or hidden.

### Remaining Risks or Follow-up Work

- Publish the reviewed source tag and all four release assets, verify anonymous public downloads and the stable appcast, and remove the temporary archives, exports, test fixture/server, and logs.
- Existing full-screen-test, physical-device, older-macOS/Intel, and performance follow-ups remain open. The app inside the archives is notarized; no separate DMG-container notarization is claimed.


## 2026-11-14 — Publish and Verify 1.1.0 with Its Signed Appcast

### Summary

- Publish the reviewed 1.1.0 release as the latest stable version at 14:07:55 UTC, using annotated tag `v1.1.0` at `da05483dd5c0a91683499312d488b79665a3bd6d`.
- Publish the notarized universal DMG and ZIP, checksum file, and signed `appcast.xml` together. The stable latest-release appcast URL is now live; both README language sections point to 1.1.0 downloads.
- Retain final packages and concise public verification metadata, and remove the task's temporary archives, exports, localhost server, local upgrade fixture, isolated update preferences/cache, verification downloads, and Xcode distribution logs.

### Affected Files

- `doc/current.md` and `doc/devlog.md`
- Remote `main`, `v1.1.0`, and https://github.com/BoboX-NPU/USBDisplay/releases/tag/v1.1.0
- Ignored `.build/Distribution/USBDisplay-1.1.0-macOS-universal.Z1FBwb/public-download-verification.json`

### Validation

- Before publication, all four draft asset digests and sizes matched the validated local files, and draft release notes matched `doc/releases/v1.1.0.md`. GitHub release ID is `445338271`.
- After publication, anonymous downloads of DMG, ZIP, checksums, and appcast matched local bytes and hashes. Sizes: DMG 2,947,486 bytes; ZIP 2,803,304 bytes; checksum file 284 bytes; appcast 3,316 bytes. The public README matches source and all six download links target verified assets.
- The stable latest-release appcast is byte-identical to the versioned signed asset. Feed signature, build/version 8/1.1.0, immutable ZIP URL, and ZIP Ed25519 signature all verified. GitHub reports 1.1.0 as latest, and the public annotated tag resolves to the reviewed release commit.
- Both apps extracted from public downloads were marked with download quarantine and passed strict signatures, stapled-ticket validation, Gatekeeper (`Notarized Developer ID`), and `syspolicy_check distribution`. Both contain arm64/x86_64, version/build 1.1.0/8, and the production feed URL. The DMG retains the Applications shortcut, Finder metadata, and background resource.
- Previous 1.0.3 DMG, ZIP, and checksum digests remain unchanged. The signed local baseline upgrade and exact payload equality are recorded in the preceding entry; no public fake update was used.
- Git whitespace checks passed. Additional application builds/tests for this publication-record-only change: Not run. The known application-test limitations remain recorded above; no blanket full-suite pass is claimed.

### Remaining Risks or Follow-up Work

- Users of 1.0.3 and earlier must manually install 1.1.0 once before in-app updating is available. Every future stable release must include a newly signed appcast and preserve compatible prior feed items.
- Existing full-screen integration-test, physical-device, older-macOS/Intel, and performance follow-ups remain open. No separate notarization of the DMG container is claimed.
