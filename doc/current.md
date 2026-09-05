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
- Shows identified model/profile status or identifying, ambiguous, unavailable, and unlisted-model states in the device row. Unknown or unresolved products use zero custom radius. Manual sliders are removed; legacy preference data is preserved but never applied.
- Reports no-device, connecting, unlock/trust, connected, interrupted, occupied, unavailable, permission-denied, and failure states. Bounded capture retries remain local to each window.

## Architecture

- `DeviceCatalog` owns capture discovery and an independent `DeviceIdentityService` refresh lifecycle.
- `USBDeviceInfoClient` implements bounded local protocol I/O. `DeviceIdentityMatcher` performs conservative name association. [Protocol and compatibility details](usb-device-identification.md).
- `DisplayWindowScene`, `DeviceWindowRegistry`, and `AppModel` retain SwiftUI lifecycle, window ownership, device selection, and per-window capture state.
- `CaptureCoordinator` handles session input, permission, reconnect, stabilization, and retry behavior.
- `WindowSurfaceLayout` calculates outside-versus-overlay chrome and local child rectangles. `WindowGeometryState` separates preferred preview geometry from current fitted placement.
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
- Latest Debug and Release builds, strict Swift-format lint, whitespace checks, and strict bundle signature verification: Passed. The canonical build/run script verified the final Debug process. Debug and Release resources match the generated catalog and MIT notices byte for byte. The running app identified iPhone 16 Pro and displayed live video after native Zoom recovered an initially narrow black preview. Expanded and compact snapshots, including a subsequent native Zoom size change, showed the video reaching the straight edges. Continuous pointer-resize acceptance remains outstanding.
- Latest full regression run: 69 Swift tests passed with no failures or skips. Nine Python generator tests also passed, including reproducibility, complete prior identifier coverage, conflict rejection, schema changes, and nonexecution of downloaded metadata. Coverage includes filtering, routing, retry classification, profiles, protocol framing and fragmented sockets, cancellation/timeouts, stale results, geometry at each commit, resize proposals, full-screen restoration, multiple windows, and composed AppKit rendering. A real SwiftUI scene test also checks compact keyboard-focus eligibility and restored native buttons.
- Rendering tests use changing red/blue synthetic frames through the actual preview container inside SwiftUI hosting and the native frame hierarchy at the iPhone 402 / 874 ratio and fractional proposed sizes. They check the center, all four outermost edge pixels in every chrome state, and compact corner alpha, composited over light and dark backgrounds. Additional checks cover 80 immediate fractional-geometry chrome commits without a forced follow-up layout and 40 direct preview size changes before deferred layout. Edges are compared with the rendered center in the same color space. These tests do not measure WindowServer decorations, frame pacing, or physical video latency.
- Detailed results and hardware/tool limitations for the latest change are recorded in the final entry of [the development log](devlog.md).

## Constraints and Outstanding Validation

- The fractional right-edge gap is reproduced and fixed at the first committed layout; compact live snapshots after native Zoom showed no added straight-edge border. Final titlebar-only hover and continuous pointer-resize checks remain incomplete: computer-use coordinate actions repeatedly returned `noWindowsAvailable` while accessibility menus and screenshots still worked. AppKit bitmap tests and native Zoom endpoints do not establish continuous WindowServer behavior.
- Startup still needs investigation: an initially narrow restored window showed a black preview until native Zoom produced visible video. This is separate from the corrected fractional edge gap and is not claimed resolved.
- Real pointer drags from all eight handles, fast consecutive drags, and hover/resize interleaving need valid intermediate pointer events and physical acceptance. Delegate proposals and endpoint screenshots cannot establish drag smoothness or anchoring.
- WindowServer frame-by-frame recording of actual video over contrasting desktop content remains separate from the AppKit bitmap tests. JPEG-only UI screenshots cannot independently prove alpha or absence of a one-frame flash.
- The 164 catalog entries are metadata/test coverage, not physical validation of 164 devices. Six uncorroborated BezelKit identifiers remain excluded; future rounded models require measured geometry and reviewed mappings. Older-device metadata does not guarantee USB capture compatibility.
- Physical iPhone 17 Pro / Pro Max, iPad, rotation, hot unplug/replug, monitor-edge movement/overlay, and concurrent capture with multiple connected devices remain hardware checks. Fixtures do not count as physical runs of unavailable products.
- macOS 14/15 toolbar behavior, occupied-device recovery, permission denial, a 30-minute multi-window soak, production signing, notarization, distribution, and external performance measurements remain outstanding.
- Local builds are ad-hoc signed; rebuilding can require camera permission again. Xcode disables hardened runtime for the Debug ad-hoc build.
- DRM-protected content may appear black; the app does not bypass platform protections.
