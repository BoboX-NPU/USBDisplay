# USB Display Current Project State

## Overview

USB Display is a native macOS 14+ SwiftUI application that displays the screen of a USB-connected iPhone or iPad. Version 0.3.0 is a standard Xcode macOS application with an app target, a unit-test target, a shared scheme, project-owned bundle metadata, and project-owned entitlements.

The application uses only public AVFoundation and CoreMediaIO APIs. It does not install a mobile companion app and does not send input, control commands, audio, recordings, screenshots, or captured frames to any destination.

## Current Capabilities

- Explicitly enables CoreMediaIO screen-capture-device discovery and disables wireless screen-capture discovery.
- Discovers wired Apple devices that provide external muxed screen media, including sources that macOS reports with the Other transport type.
- Publishes device discovery through one application-level catalog shared by every window.
- Uses a value-based SwiftUI `WindowGroup` keyed by the device unique ID and retains at most one window for each selected device.
- Switches the current window directly when the user left-clicks an unclaimed device.
- Provides `Open in New Window` from each device row's context menu; selecting a device that already owns a window focuses that window instead of duplicating its capture session.
- Gives each device window its own `AVCaptureSession`, connection state, retry lifecycle, sidebar state, and live preview aspect ratio.
- Releases only the closing window's capture session; another device window continues independently.
- Uses `AVCaptureVideoPreviewLayer` with `.resizeAspect` for the system-managed direct-preview path supported by wired iPhone and iPad screen sources.
- Reports the effective preview content rectangle back to the window model and updates the window aspect ratio when the source orientation changes.
- Keeps a normal window's detail area at the exact source aspect ratio, with no white inset, letterbox, stretching, or cropping.
- Keeps a per-window in-memory preferred preview rectangle. Orientation changes preserve its height; chrome and screen fitting never overwrite the preferred size. User resizing commits a new preference, and user movement translates it.
- Constrains live resizing through a forwarding `NSWindowDelegate` before each proposed size is applied, subtracting the sidebar, divider, and title bar. An ordinary drag has no release animation or second ratio snap.
- Debounces sidebar-width measurements for 0.1 seconds and routes all programmatic frame changes through one cancellable transition. Starting a user resize cancels pending frame work and suspends hover chrome until release.
- Uses a native `NavigationSplitView` with a collapsible system sidebar containing device names and selection state.
- Uses a separate native title bar with its system background and separator while the sidebar is visible, keeps the logical window title visually hidden, and places the sidebar and display surface below it.
- Replaces the automatically positioned split-view toggle with one AppKit navigational toolbar item beside the traffic-light controls. It uses the native responder chain and exposes dynamic `Show Sidebar` and `Hide Sidebar` accessibility labels.
- Collapses the complete title bar when the sidebar is hidden, including its material, separator, traffic-light buttons, toolbar, and sidebar button, so the compact window contains only the device display surface.
- Reveals the complete native title bar when the pointer enters the compact window's full-width 8-point top region. The revealed region includes the title bar and an 8-point bridge below it; leaving that region collapses the title bar after 0.5 seconds, while re-entering cancels the pending collapse.
- Measures the native title bar at runtime and uses one 0.15-second frame transition. Sidebar space is added to the left of the preferred preview rectangle and title-bar space above it. Fitting first translates the window, then scales the preview only if necessary; removing chrome restores the preferred rectangle.
- Reports actual compact chrome back to SwiftUI and extends the detail view through its top safe area only in fully compact mode, preventing the hidden native title bar from leaving a 32-point empty inset.
- Applies a continuous transparent-window corner mask only in fully compact mode. Automatic profiles require an exact public capture `modelID` match in an 80-model Apple Simulator display-reference table. Radii scale with the preview short side and do not change on rotation. Unknown identifiers use zero custom radius until manually calibrated; device names and aspect ratios never select a model profile.
- Provides `Adjust Screen Corners…` from each device row's context menu with Automatic and Custom modes, a 0–20% slider in 0.5% steps, a live outline preview, reset, and explicit matched/manual/unmatched status. Per-device overrides retain the existing SHA-256 preference keys and take precedence over model profiles.
- Restores the native opaque window presentation and removes the custom mask whenever the title bar is visible or the window is full screen.
- Uses aspect-fit black bars only as the explicit native full-screen exception, where the display ratio cannot be changed to match the device.
- Reports no-device, unlock-or-trust, connecting, connected, interrupted, occupied, device-unavailable, camera-permission, and general failure states within the display surface.
- Retries suspended, occupied, interrupted, and transiently failed devices with bounded delays local to that window.
- Emits structured device, session, interface, and diagnostic error logs without device identifiers or captured content.

## Architecture

- `DeviceCatalog` owns the application-level CoreMediaIO configuration and AVFoundation device discovery monitor.
- `DisplayWindowScene` owns a window's `AppModel`, routes left-click switching, and opens or focuses context-menu device windows.
- `DeviceWindowRegistry` atomically transfers device ownership between the current selection and other windows.
- `AppModel` owns one window's selected device ID, sidebar presentation and measured width, live aspect ratio, and capture coordinator.
- `CaptureCoordinator` owns one window's independent capture session, permission handling, connection state, reconnect handling, stabilized connection reporting, and bounded retries.
- `PreviewHostView` is the narrow AppKit bridge that hosts `AVCaptureVideoPreviewLayer` and measures its effective content rectangle.
- `DisplayCornerProfileResolver` returns a matched model name, normalized radius, and reference source, or an explicit unmatched profile. `doc/device-corner-profiles.md` records calibration units, source bundles, and SHA-256 hashes.
- `CornerRadiusPreferences` owns local per-device overrides and persists only SHA-256-derived preference keys.
- `WindowLayoutPolicy` provides aspect validation, sidebar-aware sizing, screen-bound fitting, and the three-state chrome policy. `WindowGeometryState` separates preferred preview geometry from fitted frames; `WindowFrameTransition` interpolates one cancellable frame transition.
- `WindowLayoutCoordinator` is the narrow AppKit window bridge that owns the leading sidebar toolbar item, applies compact or native window presentation, tracks the local top-edge reveal region, owns the forwarding resize delegate, one frame timer, and per-window geometry. It preserves ordinary-window geometry and sidebar visibility across full-screen transitions while retaining SwiftUI's window ownership and forwarding its original delegate methods.
- Pure device filtering, device-window routing, ownership transfer, corner-profile resolution, preference persistence, proportional window layout, error classification, and retry behavior are covered by Swift Testing tests.

## Public API Boundaries

The connected iPhone and iPad screen sources expose opaque public formats with `0 x 0` dimensions and no public frame-rate range. Although AVFoundation session presets are real APIs, accepting a preset does not prove that these USB sources transmit at the preset's named resolution. The app therefore provides no Auto, 1080p, or 4K controls, sets no session preset, and leaves stream negotiation to AVFoundation.

The compatible `AVCaptureVideoPreviewLayer` path exposes no public latency-control parameter or per-frame capture-to-display timing. The app provides and claims no latency adjustment. End-to-end latency requires an external measurement.

AVFoundation exposes a `modelID` but no public physical display-corner radius. The app matches exact identifiers against checked-in Apple Simulator display-reference measurements, not live hardware radius values. Generic or otherwise unlisted identifiers require manual calibration. The app neither reads simulator files at runtime nor calls private device APIs. Source provenance and the logical-point normalization formula are in `doc/device-corner-profiles.md`.

A previously tested `AVCaptureVideoDataOutput` and `AVSampleBufferDisplayLayer` path was removed because the physical iPad screen source caused CoreMediaIO to reject stream startup with the `!dev` status even with device-native output settings. The direct preview layer remains the compatible public presentation path for this source.

## Build and Run

- `USBDisplay.xcodeproj` defines the USB Display macOS app target, iPhoneUSBDisplayTests unit-test target, and shared USB Display scheme.
- `Config/Info.plist` and `Config/USBDisplay.entitlements` own the version 0.3.0 metadata, unchanged `com.xuemingbo.iPhoneUSBDisplay` bundle identifier, explicit camera-device entitlement, and USB mobile-screen permission explanation.
- `script/build_and_run.sh` is the canonical local entry point with run, debug, logs, telemetry, and verify modes. It builds into the project-local `.build/Xcode` DerivedData directory and launches `USB Display.app` directly.
- `.codex/environments/environment.toml` exposes the Xcode-backed script as the Codex Run action.

## Validation Status

- Swift format lint: Passed with no warnings.
- Xcode Debug and Release builds: Passed.
- Xcode unit and AppKit integration tests: 54 tests passed across eight suites.
- Build, launch, and process verification through `script/build_and_run.sh --verify`: Passed.
- Actual connected-iPhone sidebar round trips: Passed 20 consecutive cycles. Compact frames remained 243 x 527 points and expanded frames remained 406 x 579 points in every cycle, with a 52-point title bar and no cumulative size drift.
- Actual connected-iPhone compact safe-area check: Passed after correcting the 32-point top inset discovered during this task. Compact and expanded previews fill their available detail surfaces; hover chrome reserves its own title-bar space.
- Actual expanded and compact native full-screen round trips: Passed. Exit restored the respective 406 x 579 and 243 x 527 sizes and the original sidebar visibility. Full screen retained aspect-fit bars.
- Actual corner-adjustment panel: Passed. The connected device was explicitly unmatched; Custom accepted 10.0%, and Reset returned it to unmatched Automatic at 0.0%. The original automatic preference was restored after testing.
- Automated NSWindow integration checks: Passed 20 sidebar cycles, interrupted frame transitions, width/height/diagonal resize proposals without release correction, delegate forwarding, compact safe-area signaling, and simulated full-screen restoration.
- Physical pointer resizing: Attempted, but not validated. Computer Use generated live-resize begin/end events without intermediate resize proposals or an actual size change. This does not establish real drag responsiveness or anchoring.

## Constraints and Outstanding Validation

- Apple does not guarantee concurrent capture from two external mobile screen devices on macOS. Earlier two-device capture succeeded, but the updated left-click and context-menu interaction requires another live two-device run.
- Normal-window sizing is driven by the effective live preview rectangle. Until a valid stream ratio is available, the window keeps its current size and shows the black connection surface.
- Manual resizing from every edge and corner, fast successive drags, and hover/resize interleaving require physical-pointer verification. The real AppKit integration tests cover sizing proposals and interruption behavior, not pointer-handle routing.
- No iPad or live source with a matched exact model identifier was available for final validation. Automatic reference-profile appearance, physical rotation, and iPad live resizing were not run; model matching, radius scaling, and manual fallback are tested.
- Dynamic physical rotation, dragging the sidebar divider with a live stream, screen-edge fitting on an actual display, hot unplug/replug, camera permission denial, occupied-device recovery, and a 30-minute two-window soak remain to be run.
- Native full screen cannot simultaneously match an arbitrary device ratio and the fixed display ratio; the application preserves the complete image and uses black bars in that mode.
- Compact title-bar reveal is monitored only through local events and tracking areas inside each application window and does not require a global event monitor or Accessibility permission.
- End-to-end latency and sustained frame rate were not measured. The direct-preview path does not expose the required timing data.
- The local build is ad-hoc signed because no valid development signing identity is installed. Xcode disables hardened runtime for the Debug ad-hoc build, and rebuilds may require camera permission again.
- DRM-protected content may display black; the app intentionally does not bypass platform protection.
- App Store packaging, production signing, notarization, and distribution remain outside this local MVP.
