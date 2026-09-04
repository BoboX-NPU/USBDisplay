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
- Preserves the current height when the device ratio changes and adjusts width, shrinking proportionally when the result would exceed the current display's visible area.
- Allows unconstrained live window resizing while the preview remains aspect-fit, then performs one 0.12-second ratio snap after the drag ends. The snap accounts for the current sidebar width and preserves the edge opposite the active resize handle.
- Debounces sidebar-width changes for 0.1 seconds and coalesces noninteractive device, orientation, and chrome layout requests so only the latest proportional resize is applied.
- Uses a native `NavigationSplitView` with a collapsible system sidebar containing device names and selection state.
- Uses a separate native title bar with its system background and separator while the sidebar is visible, keeps the logical window title visually hidden, and places the sidebar and display surface below it.
- Replaces the automatically positioned split-view toggle with one AppKit navigational toolbar item beside the traffic-light controls. It uses the native responder chain and exposes dynamic `Show Sidebar` and `Hide Sidebar` accessibility labels.
- Collapses the complete title bar when the sidebar is hidden, including its material, separator, traffic-light buttons, toolbar, and sidebar button, so the compact window contains only the device display surface.
- Reveals the complete native title bar when the pointer enters the compact window's full-width 8-point top region. The revealed region includes the title bar and an 8-point bridge below it; leaving that region collapses the title bar after 0.5 seconds, while re-entering cancels the pending collapse.
- Measures the native title-bar height at runtime and animates the outer frame over 0.15 seconds. The temporary title bar adds space above the display surface instead of covering or resizing it, and the compact frame is restored after collapse.
- Applies a continuous transparent-window corner mask only in fully compact mode. Automatic profiles use 14% of the short side for modern long-screen iPhones, 0% for classic 16:9 iPhones, 3% for iPads, and 0% for unknown devices; rotation does not change the normalized profile.
- Provides `Adjust Screen Corners…` from each device row's context menu with Automatic and Custom modes, a 0–20% slider in 0.5% steps, a live outline preview, and reset support. Per-device overrides are stored locally under a one-way hash of the unique ID.
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
- `DisplayCornerProfileResolver` classifies public device metadata and calculates normalized automatic or custom corner geometry.
- `CornerRadiusPreferences` owns local per-device overrides and persists only SHA-256-derived preference keys.
- `WindowLayoutPolicy` provides testable aspect validation, sidebar-aware sizing, screen-bound fitting, post-drag snapping and edge anchoring, the three-state window-chrome policy, title-bar frame compensation, and the full-screen exception.
- `WindowLayoutCoordinator` is the narrow AppKit window bridge that owns the leading sidebar toolbar item, applies compact or native window presentation, tracks the local top-edge reveal region, manages live-resize and coalesced layout state, preserves sidebar state across full-screen transitions, and corrects the `NSWindow` frame without replacing SwiftUI's window ownership.
- Pure device filtering, device-window routing, ownership transfer, corner-profile resolution, preference persistence, proportional window layout, error classification, and retry behavior are covered by Swift Testing tests.

## Public API Boundaries

The connected iPhone and iPad screen sources expose opaque public formats with `0 x 0` dimensions and no public frame-rate range. Although AVFoundation session presets are real APIs, accepting a preset does not prove that these USB sources transmit at the preset's named resolution. The app therefore provides no Auto, 1080p, or 4K controls, sets no session preset, and leaves stream negotiation to AVFoundation.

The compatible `AVCaptureVideoPreviewLayer` path exposes no public latency-control parameter or per-frame capture-to-display timing. The app provides and claims no latency adjustment. End-to-end latency requires an external measurement.

AVFoundation exposes a stable `modelID` for devices of the same model but no public physical display-corner radius. The app therefore treats its automatic percentages as visual profiles rather than exact Apple hardware specifications.

A previously tested `AVCaptureVideoDataOutput` and `AVSampleBufferDisplayLayer` path was removed because the physical iPad screen source caused CoreMediaIO to reject stream startup with the `!dev` status even with device-native output settings. The direct preview layer remains the compatible public presentation path for this source.

## Build and Run

- `USBDisplay.xcodeproj` defines the USB Display macOS app target, iPhoneUSBDisplayTests unit-test target, and shared USB Display scheme.
- `Config/Info.plist` and `Config/USBDisplay.entitlements` own the version 0.3.0 metadata, unchanged `com.xuemingbo.iPhoneUSBDisplay` bundle identifier, explicit camera-device entitlement, and USB mobile-screen permission explanation.
- `script/build_and_run.sh` is the canonical local entry point with run, debug, logs, telemetry, and verify modes. It builds into the project-local `.build/Xcode` DerivedData directory and launches `USB Display.app` directly.
- `.codex/environments/environment.toml` exposes the Xcode-backed script as the Codex Run action.

## Validation Status

- Swift format lint: Passed with no warnings.
- Xcode Debug build: Passed.
- Xcode Release build: Passed.
- Xcode unit tests: 48 tests passed across six suites.
- Debug build and process verification: Passed through `script/build_and_run.sh --verify`.
- Project file, Info.plist, and entitlements property-list lint: Passed.
- Built application signature: Passed strict ad-hoc `codesign` verification; the camera-device entitlement is present.
- Running-app iPhone safe-area check on macOS 27: Passed. The status bar and Dynamic Island area remained fully visible below the expanded native title bar.
- Running-app sidebar-control check: Passed. The only sidebar button appeared directly beside the traffic lights, changed between `Hide Sidebar` and `Show Sidebar`, collapsed the sidebar, and expanded it again from temporary hover chrome.
- Running-app corner check: Passed. The connected iPhone used rounded transparent compact chrome; hover-revealed, expanded, and full-screen states used the native Mac window presentation.
- Running-app corner-adjustment check: Passed. The device context menu opened the panel, Automatic and Custom modes switched correctly, the slider accepted a 10.0% value, Reset restored the automatic 14.0% profile, and Done dismissed the panel.
- Running-app resize check: Passed with the expanded sidebar. A bottom-right live drag grew the window from 311 x 372 to 452 x 680 points, and the settled detail area filled the live portrait source at its exact ratio without permanent black bars, cropping, or stretching.
- Running-app multiwindow chrome check: Passed. Two typed windows were present and retained independent sidebar and title-bar appearance state.
- Native full-screen round trip: Passed. Full screen used aspect-fit black bars without a custom corner mask, and exiting restored the expanded sidebar and native title bar.
- Running-app context-menu check: Passed. `Open in New Window` is available and selecting it for the current device focuses the existing typed window instead of creating a duplicate.
- The connected iPhone produced a live preview throughout the final layout, corner, resize, and full-screen checks.

## Constraints and Outstanding Validation

- Apple does not guarantee concurrent capture from two external mobile screen devices on macOS. Earlier two-device capture succeeded, but the updated left-click and context-menu interaction requires another live two-device run.
- Normal-window sizing is driven by the effective live preview rectangle. Until a valid stream ratio is available, the window keeps its current size and shows the black connection surface.
- All eight resize-handle anchoring cases, minimum sizing, screen fitting, sidebar accounting, portrait and landscape ratios, and the full-screen exception are covered by pure policy tests. Physical pointer checks of every individual handle and rapid repeated resize gestures remain to be run.
- No iPad was available for the final build, so its automatic 3% compact corners, physical rotation, and live resizing were not run; the iPad classification and orientation-independent calculation are covered by unit tests.
- Dynamic physical rotation, sidebar-width changes with a live stream, hot unplug/replug, camera permission denial, occupied-device recovery, and a 30-minute two-window soak remain to be run.
- Native full screen cannot simultaneously match an arbitrary device ratio and the fixed display ratio; the application preserves the complete image and uses black bars in that mode.
- Compact title-bar reveal is monitored only through local events and tracking areas inside each application window and does not require a global event monitor or Accessibility permission.
- End-to-end latency and sustained frame rate were not measured. The direct-preview path does not expose the required timing data.
- The local build is ad-hoc signed because no valid development signing identity is installed. Xcode disables hardened runtime for the Debug ad-hoc build, and rebuilds may require camera permission again.
- DRM-protected content may display black; the app intentionally does not bypass platform protection.
- App Store packaging, production signing, notarization, and distribution remain outside this local MVP.
