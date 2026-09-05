# USB Display Current Project State

## Overview

USB Display is a native macOS 14+ SwiftUI application for displaying a USB-connected iPhone or iPad. Version 0.3.0 uses a standard Xcode app target, shared scheme, unit-test target, project-owned bundle metadata, and camera-device entitlement.

Capture uses public AVFoundation and CoreMediaIO APIs. A separate read-only client of the local usbmuxd/lockdownd protocols identifies product models. No companion app, Xcode installation, private Apple framework, recording, audio capture, remote transmission, or mobile input control is required.

## Current Capabilities

- Enables wired CoreMediaIO screen sources and disables wireless discovery. Accepts eligible external muxed Apple devices even when their public transport type is `Other`.
- Shares one device catalog across SwiftUI `WindowGroup` windows, with at most one window per selected device. Left-click switches the current window or focuses an existing owner; `Open in New Window` preserves the existing multi-window route.
- Gives each window an independent capture session, retry lifecycle, connection status, sidebar state, preview ratio, and ordinary-window geometry. Closing a window releases only its session.
- Retains the compatible `AVCaptureVideoPreviewLayer` path. Each window owns one persistent preview view and layer, including across sidebar, titlebar, safe-area, and full-screen changes. Ordinary windows with a known source ratio use aspect fill to cover the small remainder from AppKit frame rounding; full screen, transitions, and unknown geometry retain aspect fit.
- Hosts the preview, SwiftUI device list, connection overlay, and control backgrounds in an explicit AppKit container. The preview no longer participates in `NavigationSplitView` sizing.
- Uses a responsive 30% sidebar / 70% content split when no active source ratio is available, including no-device, selection, and connection placeholders. Empty windows resize freely within screen bounds and have a nominal 720-by-480-point minimum, capped by the screen; AppKit may add native toolbar height. Late narrow frame restoration is repaired synchronously. Hiding the sidebar gives the content the full width.
- Stores the empty-window frame separately from the preferred video rectangle for each window. A connected source restores proportional video sizing and its smaller minimum; disconnecting restores the empty layout. Changes arriving during a drag wait for release, and full-screen transitions retain ordinary geometry.
- Commits the complete outer frame and child frames together with implicit Core Animation actions disabled. Child frames use the actual window frame accepted by AppKit, including its quantization, so fractional requests cannot leave an uncovered right strip. There is no timer-driven outer-frame animation, preview snapshot substitution, or delayed resize correction.
- Adds sidebar space to the left and titlebar space above the preferred preview rectangle. Screen-edge fitting translates the window without scaling the preview. If the combined dimensions cannot fit, controls overlay the preview along the constrained axis; closing them restores the preferred geometry.
- Keeps preferred geometry in memory per window. User movement translates it; user resizing replaces the preferred size. Source rotation preserves the preferred height and fits the new orientation to the screen independently of chrome.
- Constrains AppKit resize proposals before application, subtracting the currently external sidebar, divider, and titlebar. Hover changes are suspended during a drag. Shadow invalidation happens at chrome commits or resize completion, not each resize proposal.
- Preserves SwiftUI's window lifecycle and forwards its original window delegate behavior. An explicit native navigational toolbar item toggles the AppKit sidebar and exposes `Show Sidebar` / `Hide Sidebar` accessibility labels.
- Keeps native window buttons when controls are visible. Compact mode hides toolbar/buttons/background; an 8-point top region reveals the titlebar, with an 8-point bridge and a 0.5-second hide delay. Local events require no global monitor or Accessibility permission for the application itself.
- Keeps the window and app-owned container transparent at all times. Black is drawn only inside the preview surface. The compact continuous-corner mask belongs to the preview, not the SwiftUI root layer. Expanded controls draw their own backgrounds.
- Disables the system window shadow in compact mode so it cannot expose the rectangular window behind the rounded preview. Expanded controls restore the original shadow setting. The native window style remains intact for keyboard focus, window buttons, and macOS 14 compatibility.
- Uses the complete full-screen surface with aspect-fit black bars. The system manages full-screen toolbar reveal; the app does not retain an empty titlebar strip. Exiting restores ordinary geometry and the previous sidebar state, adapting to any source rotation that occurred during full screen.
- Queries only USB `ProductType` and `DeviceName` off the main thread. Exact names must be unique in both complete capture and USB snapshots. Duplicate names are unresolved, and stale query generations cannot update a replaced device list.
- Automatically matches exact USB product types against 164 bundled reference profiles: 60 iPhone and 104 iPad identifiers. Apple Simulator geometry is extended through explicit DeviceKit hardware groups and cross-checked with BezelKit. Radius scales by the displayed short side and uses the same normalized value in either orientation.
- Shows a single model label in each device row, such as `iPhone 16 Pro`, without corner or identification-status annotations. Unlisted products fall back to their ProductType; devices without a resolved product use their capture name. Unknown or unresolved products still use zero custom radius. Manual sliders are removed; legacy preference data is preserved but never applied.
- Reports no-device, connecting, unlock/trust, connected, interrupted, occupied, unavailable, permission-denied, and failure states. Bounded capture retries remain local to each window.

## Architecture

- `DeviceCatalog` owns capture discovery and an independent `DeviceIdentityService` refresh lifecycle.
- `USBDeviceInfoClient` implements bounded local protocol I/O. `DeviceIdentityMatcher` performs conservative name association. [Protocol and compatibility details](usb-device-identification.md).
- `DisplayWindowScene`, `DeviceWindowRegistry`, and `AppModel` retain SwiftUI lifecycle, window ownership, device selection, and per-window capture state.
- `CaptureCoordinator` handles session input, permission, reconnect, stabilization, and retry behavior.
- `WindowSurfaceLayout` calculates outside-versus-overlay chrome, local child rectangles, and the balanced placeholder split. `WindowGeometryState` separates preferred preview geometry from current fitted placement. `ContentView` excludes a retained capture ratio while the connection status is not connected.
- `WindowLayoutHostView` owns the stable children, native toolbar, forwarding resize delegate, hover tracking, and synchronous geometry commits.
- `PreviewHostView` synchronizes preview-layer bounds, its own corner mask, and backing scale in nonanimated transactions, including direct frame/bounds changes before deferred layout. Unchanged geometry and video gravity are not reassigned. Its half-second timer only detects source aspect changes; it does not animate frames.
- `DisplayCornerProfileResolver` validates and loads the bundled JSON catalog once, then resolves exact USB product types. Invalid catalogs fall back to unmatched profiles.
- `script/update_device_profiles.py` reproducibly generates the offline catalog, source audit, and bundled MIT notices from pinned and hashed inputs. Unreviewed source conflicts stop generation. [Sources and update workflow](device-corner-profiles.md); [complete model catalog](device-corner-catalog.md).

## API and Compatibility Boundaries

Wired mobile screen sources expose opaque public formats with `0 x 0` dimensions and no public frame-rate range. The app sets no session preset and makes no native-resolution, latency-control, or sustained-frame-rate claim. End-to-end latency requires external measurement.

The previous `AVCaptureVideoDataOutput` / `AVSampleBufferDisplayLayer` implementation was removed after the physical iPad source rejected startup with `!dev`; direct preview remains the supported path in this project.

The connected iPhone's capture model is `iOS Device`; the read-only USB query resolves `iPhone17,1` (iPhone 16 Pro). usbmuxd/lockdownd are not an Apple-guaranteed public SDK. Identity failures remain independent of capture. There are no pairing changes or authenticated session requests.

Rounded corner values are traceable Simulator display-reference measurements, not live physical hardware measurements. Older square displays can also use a zero radius corroborated by DeviceKit and BezelKit. The conflicting iPad Air 3 profile is explicitly resolved to zero; known BezelKit mapping errors are corrected or excluded. iPhone 16 Pro and iPhone 17 Pro share 62 / 402 in the source; iPhone 17 Pro Max uses 62 / 440. The app does not fabricate differences, infer a specific model from a name/aspect ratio, or read simulator files at runtime.

## Build and Validation

- Canonical build/run command: `./script/build_and_run.sh --verify`, using `.build/Xcode` and the shared `USB Display` scheme. The Codex Run action calls this script.
- Latest empty-layout update: Debug and Release builds, canonical `./script/build_and_run.sh --verify`, strict recursive Swift-format lint, whitespace checks, and strict Debug/Release bundle signature verification passed.
- Latest full regression run: 75 Swift tests passed with zero failures and zero skips. Six new checks cover the 30/70 split, screen fitting, late narrow restoration, freeform empty resizing, independent empty/video/multi-window state, device arrival during resizing/full-screen transitions, and actual SwiftUI empty content with a retained phone ratio. Existing geometry, rendering, capture, identity, and catalog tests passed. The nine Python catalog-generator tests passed in the earlier catalog update and were not rerun for this Swift-only change.
- Running-app inspection: a newly opened `Select a device` window showed a 294-point sidebar inside a 980-point window, with the remaining 686 points for content. Native Zoom preserved the approximate 30/70 split; the window was restored to its initial size. The device row displayed only `iPhone 16 Pro`. Physical no-device startup/unplug and continuous pointer resizing were not run in this check; the disconnected case passed the real SwiftUI-hosting fixture.
- Rendering tests use changing red/blue synthetic frames through the actual preview container inside SwiftUI hosting and the native frame hierarchy at the iPhone 402 / 874 ratio and fractional proposed sizes. They check the center, all four outermost edge pixels in every chrome state, and compact corner alpha, composited over light and dark backgrounds. Additional checks cover 80 immediate fractional-geometry chrome commits without a forced follow-up layout and 40 direct preview size changes before deferred layout. Edges are compared with the rendered center in the same color space. These tests do not measure WindowServer decorations, frame pacing, or physical video latency.
- Detailed results and hardware/tool limitations for the latest change are recorded in the final entry of [the development log](devlog.md).

## Constraints and Outstanding Validation

- The fractional right-edge gap is reproduced and fixed at the first committed layout; compact live snapshots after native Zoom showed no added straight-edge border. Final titlebar-only hover and continuous pointer-resize checks remain incomplete: computer-use coordinate actions repeatedly returned `noWindowsAvailable` while accessibility menus and screenshots still worked. AppKit bitmap tests and native Zoom endpoints do not establish continuous WindowServer behavior.
- Empty-state narrow restoration is now covered by the balanced split and minimum-size repair. The earlier delayed/black live-preview startup remains a separate capture acceptance item; this layout update does not claim to resolve video first-frame timing.
- Real pointer drags from all eight handles, fast consecutive drags, and hover/resize interleaving need valid intermediate pointer events and physical acceptance. Delegate proposals and endpoint screenshots cannot establish drag smoothness or anchoring.
- WindowServer frame-by-frame recording of actual video over contrasting desktop content remains separate from the AppKit bitmap tests. JPEG-only UI screenshots cannot independently prove alpha or absence of a one-frame flash.
- The 164 catalog entries are metadata/test coverage, not physical validation of 164 devices. Six uncorroborated BezelKit identifiers remain excluded; future rounded models require measured geometry and reviewed mappings. Older-device metadata does not guarantee USB capture compatibility.
- Physical iPhone 17 Pro / Pro Max, iPad, rotation, hot unplug/replug, monitor-edge movement/overlay, and concurrent capture with multiple connected devices remain hardware checks. Fixtures do not count as physical runs of unavailable products.
- macOS 14/15 toolbar behavior, occupied-device recovery, permission denial, a 30-minute multi-window soak, production signing, notarization, distribution, and external performance measurements remain outstanding.
- Local builds are ad-hoc signed; rebuilding can require camera permission again. Xcode disables hardened runtime for the Debug ad-hoc build.
- DRM-protected content may appear black; the app does not bypass platform protections.
