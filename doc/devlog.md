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
