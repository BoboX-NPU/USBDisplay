# Code and Apple API Audit — 2026-09-05

## Scope and Outcome

Reviewed baseline commit `397b1f9`: all 20 production Swift files (3,300 lines), eight Swift test files (2,222 lines), two Python scripts, the build/run shell script, Xcode project and scheme, bundle configuration, resource-generation checks, and current architecture documentation. The original audit commit `f1cd67a` changed documentation only. The approved implementation is now present; see Implementation Results below. Finding descriptions and source line references in the original audit sections describe baseline `397b1f9`, not the updated files.

The capture and rendering architecture already relies heavily on Apple frameworks. The most useful next changes are corrections to source identity, asynchronous state publication, and window lifecycle handling. Replacing the entire AppKit container with another UI framework is not justified by this review.

Evidence distinguishes six defects reproduced by temporary regression probes, one capture recovery defect established by code tracing and the SDK contract, and two issues reproduced by the existing validation commands. P2 means a functional or validation issue to address; P3 means lower-priority appearance or tooling work. No P0/P1 finding was established. Physical multi-device, monitor-change, and interruption acceptance remains separate.

## Original Audit Findings

### F1 — P2: Reset ratio sampling when the capture source changes

Locations: `USBDisplay/Services/AppModel.swift:35–40`, `USBDisplay/Views/PreviewView.swift:138–162`, `USBDisplay/Views/WindowLayoutCoordinator.swift:20–25`.

Selecting a new device clears `AppModel.previewAspectRatio`, but the window retains its `AVCaptureSession`. `PreviewHostView.setSession` returns immediately for that same session, preserving the previous `StableAspectRatio.confirmed`. If the replacement device has the same ratio, every subsequent sample is suppressed. The model can remain without a ratio until the source rotates, so connected video keeps the placeholder layout and free resizing instead of proportional sizing.

The temporary probe established a 0.5 ratio, selected another device, reused the same session, and sampled 0.5 again. The model's ratio was nil and the filter returned false. This is a state-level reproduction; two physical devices were not switched.

Carry a source/session generation into the preview and reset or republish ratio state when that generation changes. Keep the stable preview layer. Add coverage for A-to-B with equal ratios and A-to-B-to-A, including stale ratio callbacks.

### F2 — P2: Reject capture snapshots from an obsolete selection

Locations: `USBDisplay/Services/AppModel.swift:67–69`, `USBDisplay/Services/CaptureCoordinator.swift:381–392`, `USBDisplay/Models/ConnectionStatus.swift:70–73`.

Capture status is delivered through a separately scheduled MainActor task. A snapshot queued for A may arrive after the user selects B. `AppModel.apply` unconditionally replaces both the selected ID and status, allowing the old callback to undo the current selection in the model while the SwiftUI scene binding and window registry still identify B. The UI can temporarily show A's title/profile/status with B's pending stream.

The temporary probe selected B, delivered an already queued A snapshot, and observed `selectedDeviceID == "a"` and an obsolete connected status.

Keep the selected ID as user intent. Stamp publications with a generation and reject obsolete callbacks, including after stop/restart. An ID-only guard is insufficient for A-to-B-to-A. Test delivery ordering explicitly rather than relying on queue timing.

### F3 — P2: Publish recovery after an automatic capture-session restart

Locations: `USBDisplay/Services/CaptureCoordinator.swift:118–125`, `156–159`, `311–327`.

The interruption handler publishes `.interrupted` or `.occupied`. On interruption end, the coordinator calls `connectSelectedDevice`; if the same input is already running again, that method republishes `currentStatus` and returns. The status can therefore stay interrupted even though AVFoundation has resumed the stream. `ContentView` continues showing the opaque status surface while this stale status remains.

The installed SDK's `AVCaptureSessionInterruptionEndedNotification` documentation explicitly permits automatic restart when an interruption ends. This finding is based on that contract and the current control flow; a physical occupied-device recovery was not forced during this audit.

Handle interruption recovery as a state transition. Revalidate the selected input and running state, invalidate obsolete retry/stabilization work, and publish a new valid connected state. Track interruption notifications locally: `AVCaptureSession.isInterrupted` is unavailable on macOS. Also invalidate a pending startup confirmation when an interruption begins so the old 250 ms confirmation cannot overwrite it.

### F4 — P2: Preserve non-live resize results before the next chrome commit

Locations: `USBDisplay/Views/WindowLayoutCoordinator.swift:779–785`, `809–820`.

Preferred preview size is updated at `endResize`, but `resized` only updates child frames and `lastWindowFrame`. A resize that does not emit the live-resize lifecycle leaves `WindowGeometryState` holding the old dimensions. The next sidebar/titlebar commit uses those old dimensions and reverses the size change.

The AppKit probe applied an accepted non-live resize, then hid the sidebar. The preview changed from the resized 274-by-548 points back to 224-by-448 points. This verifies the non-live path; native Zoom, tiling, and accessibility-driven resizing should each receive their own acceptance check.

Record legitimate ordinary-window size changes outside app-owned commits and full-screen transitions. Preserve the existing frozen-state behavior during live dragging.

### F5 — P2: Clean up failed full-screen transitions

Locations: `USBDisplay/Views/WindowLayoutCoordinator.swift:94–129`, `701–744`.

Entering or exiting full screen sets `fullScreenTransition` and freezes preview geometry. Only successful did-enter/did-exit notifications clear these flags. The delegate proxy does not handle AppKit's full-screen failure callbacks, so a failed transition can leave hover, configuration updates, resizing, and ratio publication suppressed.

The temporary AppKit probe delivered will-enter followed by `windowDidFailToEnterFullScreen`. `preview.isGeometryChanging` remained true. This is a lifecycle injection, not a forced WindowServer animation failure.

Implement the official [entry-failure callback](https://developer.apple.com/documentation/appkit/nswindowdelegate/windowdidfailtoenterfullscreen(_:)) and [exit-failure callback](https://developer.apple.com/documentation/appkit/nswindowdelegate/windowdidfailtoexitfullscreen(_:)), forwarding the original delegate as appropriate. Restore state from the actual window mode and clean up reserved chrome, animation, and pending hover work.

### F6 — P2: Refit a preview that exceeds a replacement screen

Locations: `USBDisplay/Views/WindowLayoutCoordinator.swift:746–748`, `USBDisplay/Models/WindowLayoutPolicy.swift:183–194`, `227–235`.

The screen-change observer only commits the existing geometry. `WindowSurfaceLayout.placing` translates the frame and switches controls to overlays, but never reduces an oversized preview. Only a ratio change calls `orient` to fit its dimensions. Moving a large window to a smaller display, or disconnecting an external display, can therefore retain a frame that cannot fit.

The pure layout probe moved a 1600-by-900 preview into a 1280-by-720 screen and obtained a 1600-by-900 frame at the new origin. No physical monitor was disconnected.

On screen/visible-frame changes, fit the displayed rectangle to the new bounds while retaining the preferred size separately for restoration. Cover negative screen origins, display removal, and screen changes deferred during resizing. Consider `NSApplication.didChangeScreenParametersNotification` for same-display geometry changes as well.

### F7 — P3: Refresh resolved layer colors when appearance changes

Location: `USBDisplay/Views/WindowLayoutCoordinator.swift:208–209`.

The titlebar and divider convert dynamic `NSColor` values into fixed `CGColor` values at initialization. There is no appearance-change hook to refresh them. Native toolbar/sidebar colors can change while the app-owned surfaces retain the previous appearance.

The probe constructed the host under Aqua, changed its window to Dark Aqua, and observed a white titlebar layer instead of the expected dark color (RGB approximately 0.118).

Resolve these colors under `effectiveAppearance` from [viewDidChangeEffectiveAppearance](https://developer.apple.com/documentation/appkit/nsview/viewdidchangeeffectiveappearance()). Use a native material view only if that material is desired; adding blur is not necessary to fix this defect.

### F8 — P2: Replace fixed-delay completion assumptions in USB tests

Location: `USBDisplayTests/USBDeviceInfoTests.swift:93–100`.

The full Debug run failed `timeoutIsAnExplicitUnresolvedState`: the assertion saw `.identifying` rather than `.unavailable`. The same test passed in the isolated nine-test USB suite. The test sleeps for 30 ms and assumes the independently scheduled MainActor task has already published its result. Other suites perform substantial synchronous AppKit work on the same actor.

Wait for the publication using an explicit completion signal, with a bounded failure timeout. Apply the same principle to the fixed startup sleeps in `disconnectCancelsAndLateIdentityCannotReachNewCapture`. Do not merely increase the 30 ms constant. The observed failure does not demonstrate a broken socket timeout: the actual stalled-socket deadline/cancellation test passed.

### F9 — P3: Exclude unit tests from Release Analyze

Locations: `USBDisplay.xcodeproj/xcshareddata/xcschemes/USB Display.xcscheme:24–29`, `USBDisplay.xcodeproj/project.pbxproj:175–176`.

The shared scheme marks the unit-test target `buildForAnalyzing="YES"`. Overriding Analyze to Release then compiles its `@testable import` against an app module built without `-enable-testing`, and analysis fails. The ordinary Release build succeeds for both arm64 and x86_64.

Exclude the test target from Analyze, or deliberately provide an analysis/test configuration with testability. Do not enable testability in the shipping Release configuration merely to satisfy this action. Xcode Analyze is not a comprehensive static analyzer for Swift control-flow defects.

## Apple Component and API Opportunities

| Area | Recommendation | Boundary |
| --- | --- | --- |
| Device rows | Use a SwiftUI `Button` for the primary row action, retaining the row context menu and selection indication. | Preserve single-click switching and the requirement that right-click alone must not start another capture. `List(selection:)` should only replace this after its secondary-click behavior is validated. |
| Missing-device and failure UI | Use [ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview), with the existing `ProgressView` for connecting. | Available at the macOS 14 baseline. Keep actionable device-specific descriptions; do not turn all connection states into a generic empty view. |
| Capture recovery | Use running-state KVO and existing AVFoundation interruption/start/stop notifications to drive state transitions. | A running session is not proof of a displayed first frame. Preserve that distinction in UI and diagnostics. |
| Source geometry | Investigate `AVCaptureInput.Port.formatDescriptionDidChangeNotification` and CoreMedia presentation dimensions as an event-driven geometry source. | Available on macOS, but the actual USB port must be checked for useful geometry and rotation events. Opaque mobile formats mean the current preview-coordinate fallback cannot yet be deleted. |
| Full-screen controls | Retain `windowToolbarFullScreenVisibility(.onHover)` on macOS 15+ and the AppKit macOS 14 fallback; add F5 cleanup. | Native toolbar timing is already delegated to the system. Reintroducing a manual full-screen toolbar timer would duplicate it. |
| Ordinary-window proportions | Evaluate [NSWindow.contentAspectRatio](https://developer.apple.com/documentation/appkit/nswindow/contentaspectratio) only if the content rectangle is the video rectangle. | The current sidebar/titlebar can occupy fixed external space: `(W - sidebar) / (H - titlebar) = sourceRatio`. A single whole-content ratio cannot represent every current state. Retain the proportional resize policy unless the product's geometry requirements change. |
| Appearance | Use the native appearance lifecycle to update fixed layer colors (F7). | Do not force Liquid Glass or a new visual style into a correctness fix. |
| Performance evidence | Use Instruments Time Profiler, Animation Hitches, Allocations, and `OSSignposter` around capture startup and geometry commits. | This audit contains no CPU, memory, energy, latency, or frame-pacing benchmark. Measure before claiming an optimization. |

### API substitutions to avoid

- Keep `AVCaptureVideoPreviewLayer`, AVFoundation discovery, and the public CoreMediaIO screen-source opt-in. The repository records a hardware failure of the previously attempted data-output path. A newer sample-buffer renderer is not automatically more compatible or faster.
- `AVCaptureVideoPreviewLayer.isPreviewing` and `AVCaptureSession.isInterrupted` are explicitly unavailable on macOS in the installed macOS 26.5 SDK headers. `AVCaptureSessionInterruptionReasonKey` is also unavailable. They cannot be adopted from iOS examples to fix this app.
- `AVErrorMediaServicesWereReset` is declared under `TARGET_OS_IPHONE` in that SDK. Replacing the existing documented numeric fallback with `AVError.Code.mediaServicesWereReset` is not a valid automatic macOS cleanup.
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) now also has preliminary iOS/iPadOS support; Apple's [iOS sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios) requires an app running on iOS 27+. That does not establish a replacement for this macOS 14+, USB-connected, no-companion-app capture contract.
- The usbmuxd/lockdownd wire protocol is still not an Apple-supported public SDK. This audit found no documented public API that supplies equivalent remote `ProductType`, device association, and physical display-corner geometry under the current requirements. Keep identification isolated and conservatively unresolved on failure. Replacing Darwin socket calls with another transport library would not make the protocol official.
- The continuous mask is already generated from SwiftUI's official `RoundedRectangle` and applied with Core Animation. A different corner-clipping API must reproduce live-video clipping and alpha behavior before replacing the existing tested path.

## Redundancy and Maintainability

Repository-wide reference searches identified these cleanup candidates:

| Symbol or area | Current usage | Suggested action |
| --- | --- | --- |
| `AppModel.updateSidebarWidth` | No callers. | Remove unless a resizing control is being introduced. Make the fixed width explicit. |
| `DisplayCornerProfileResolver.normalizedLongAspect` | No callers. | Remove. |
| `automaticFraction(for:aspectRatio:)` | Tests only; ignores `aspectRatio`. | Test `automaticProfile` directly and remove the misleading argument/wrapper. |
| `WindowContentSize`, `contentSize`, `sizePreservingHeight`, `shouldConstrainWindow` | An obsolete helper cluster referenced by its own old tests, not the production layout path. | Remove the cluster and redundant helper tests; retain tests of `WindowSurfaceLayout`, `WindowGeometryState`, and `ResizeSession`. |
| `DisplayDeviceKind` and `DisplayDevice.kind` | Constructed for each device, consumed only by tests. | Remove unless the UI will actually distinguish device kinds. Its concatenated name/model heuristic should not be repurposed for exact identity. |
| `compactHotZoneHeight`, `AppLogger.performance` | Declared but unused. | Use a shared constant/signposter where needed, or remove; several literal 8-point hot zones remain. |
| `layoutSurface` full-screen ternaries at lines 584–585 | Located after the full-screen branch has already been excluded. | Simplify to the current external insets. |
| Discovery KVO plus connected/disconnected notifications | Both trigger publication and a new identity refresh; every retry also constructs and sorts a fresh discovery session. | Deduplicate equal raw capture snapshots, then consider sharing a provider. Preserve discovery ordering and conservative complete-snapshot matching. |
| `WindowLayoutHostView` | A 941-line file combines toolbar construction, delegate forwarding, geometry, hover, animation reservations, and lifecycle. | Extract cohesive responsibilities after behavior fixes. Introduce test seams for capture/discovery/state delivery; do not introduce a second competing geometry state owner. |

The serial capture queue, per-window session, generation-guarded identity query, strict protocol framing/size/deadline limits, pinned data hashes, and literal-only GYB parsing all serve concrete correctness purposes. No removal is recommended for them. Periodic identity queries currently detect unlock/trust changes without a USB replug; avoid replacing the five-second refresh with an unconditional permanent cache.

One additional recovery gap needs runtime confirmation: after camera access is denied, there is no user retry action or app-activation recheck, and choosing the already selected device is a no-op. If the process survives a System Settings permission change, it may require switching away/back or relaunching. The operating system's TCC relaunch behavior was not changed or tested here.

## Original Audit Validation and Evidence

Environment: Xcode 26.6 (`17F113`), compiler commands using macOS 26.5 SDK, macOS 27.0 (`26A5425a`) on arm64. The result bundle's environment description labels macOS 27.0; the build commands identify the actual SDK.

| Check | Result |
| --- | --- |
| Full existing Debug suite | 91 tests: 90 passed, one failed, zero skipped. Failure: F8. |
| Isolated existing USB identity suite | Nine tests passed, zero failed/skipped, including the previously failing timeout test. |
| Temporary diagnostic probes | Six unique tests failed the intended corrected-behavior expectations, reproducing F1, F2, F4, F5, F6, F7. Xcode executed each in two runners; these are six findings, not twelve different tests. |
| Ordinary Release build | Passed for arm64 and x86_64; strict deep signature verification passed. |
| Release build plus Analyze | Failed at the test target's non-testable app import (F9). |
| Python tests and offline catalog `--check` | Nine tests passed; generated outputs and pinned inputs verified. |
| Strict recursive Swift-format lint | Passed for production and test Swift files. |
| Shell syntax, plist/project syntax, Git whitespace | Passed. |
| Physical capture, multi-device switching, monitor removal, TCC, continuous hover/resize recording, Instruments | Not run in this audit. |
| Canonical build/run script | Reviewed and syntax-checked; not used to relaunch the user's normal application. Xcode launched its test hosts. |

The first sandboxed Debug attempt failed because the Swift macro host could not execute. The permitted run produced the actual full-suite result above. Two function-level timeout selectors executed zero tests and are excluded from coverage; the isolated suite selector executed nine. The first diagnostic harness had a Swift Testing macro syntax error, corrected before its six probes ran.

The temporary project is `/tmp/usbdisplay-code-audit-20260905`. Its only production-source edits expose `AppModel.apply` and `PreviewHostView.aspectRatioFilter` to the probes; method bodies are unchanged. The six probes were appended to its copy of `CaptureFailureTests.swift`. No diagnostic source was added to the working repository. These tests inject states and events and do not establish the frequency of physical failures.

Local result bundles:

- `/tmp/USBDisplay-Audit-Debug-Allowed-20260905.xcresult`
- `/tmp/USBDisplay-Audit-USB-Suite-20260905.xcresult`
- `/tmp/USBDisplay-Audit-Probes-Final-20260905.xcresult`

Local logs use the corresponding names; Release logs are `/tmp/USBDisplay-Audit-ReleaseBuild-20260905.log` and `/tmp/USBDisplay-Audit-Release-20260905.log`. Temporary evidence can be removed by normal system cleanup; the observations and failure values are recorded above.

## Original Suggested Implementation Order

1. Correct F1–F3 together with generation-aware capture/preview state and deterministic ordering tests.
2. Correct F4–F6 with narrow window lifecycle tests, preserving stable video-layer ownership and native full-screen toolbar control.
3. Fix appearance and validation issues (F7–F9), then adopt standard row buttons and empty-state UI with interaction checks.
4. Remove the unused helper cluster and simplify ownership in separate focused changes. Investigate event-driven port geometry and performance only with physical-device measurements.

Each implementation should record its own test results and hardware limits. The original audit did not fix application code; the implementation and its evidence are recorded below.

## Implementation Results — 2026-09-05

All nine findings are implemented in the approved correction pass. No new dependency or minimum-OS change was introduced. The AVFoundation/CoreMediaIO direct-preview pipeline, continuous mask, native full-screen toolbar behavior, and half-second ratio fallback remain intact. The read-only USB identity protocol remains isolated; it is not represented as an Apple-supported SDK.

| Finding | Implemented correction | Formal regression or validation |
| --- | --- | --- |
| F1 | Reset ratio sampling by request/stream identity; validate source-tagged ratio callbacks while preserving the preview layer. | `CaptureStateTests.sameRatioPublishesAgainForEverySourceIncludingReturnToA`, `presentationRejectsOldRequestsSequencesAndSourceRatios`, `CaptureModelTests.sourceChangesKeepThePreviewLayerAndCaptureSession`. |
| F2 | App-owned selection; new request IDs on switch/stop/restart; increasing snapshot sequence and stale-delivery guards. | Model selection/stop/restart regression, A-to-B-to-A stale-event and confirmation tests, out-of-order snapshot checks. |
| F3 | Invalidate startup confirmation on interruption, revalidate automatic recovery, scope notification handlers to their observation generation, and re-evaluate current permission requests. | Controlled interruption-during-confirmation, automatic-running recovery, permission completion, reconnection/media-reset, occupied/suspended, and startup-failure regressions. |
| F4 | Remember actual valid ordinary non-live preview sizes, including changes during chrome animation; exclude app commits, screen fitting, and full-screen transitions. | `WindowLifecycleTests.ordinaryNonLiveResizeSurvivesChromeChanges`, `ordinaryResizeDuringChromeAnimationSurvivesReservationRelease`; native Zoom/sidebar endpoint check on the live iPad preview. |
| F5 | Forward both official full-screen failure callbacks and recover reservations, animation, ratio sampling, and hover from actual window mode. | `failedEntryForwardsAndRestoresResizeAndHover`, `failedExitKeepsFullScreenOverlayAndAllowsLaterExit`. |
| F6 | Fit the displayed rectangle separately from preferred geometry; observe window screen and application screen-parameter changes; defer fitting during gestures/transitions. | Smaller/larger-screen and negative-origin geometry, deferred screen change, resize-before-screen-event and same-display parameter notification regressions. |
| F7 | Refresh fixed layer colors inside the effective appearance callback. | Aqua-to-Dark-Aqua-to-Aqua titlebar/divider callback regression. |
| F8 | Use explicit startup/publication/completion signals with three-second failure timeouts; await superseded query completion; cancel an accepted socket connection. | All nine USB tests, including the former flaky timeout test, run in the full suite. |
| F9 | Set the test target's Analyze build participation to NO; preserve Release non-testability. | Universal Release build and Release Analyze; no test target or `-enable-testing` in the Release compilation log. |

The six temporary probes are now represented by formal capture/model/window regressions. Tests use internal production interfaces and controlled collaborators; no private property was made accessible for testing. Full-screen failures and display removal are event/geometry injections, not forced hardware or WindowServer failures.

### Components and Cleanup

- Adopt standard SwiftUI row `Button` actions and `ContentUnavailableView`; retain selected styling, context menus, descriptions, and the connecting `ProgressView`.
- Deduplicate raw discovery snapshots before identity refresh, sort name ties deterministically, and reuse the capture driver's discovery session. Keep periodic identity refresh and conservative association.
- Remove the unused sidebar setter, device-kind heuristic, performance logger, ratio wrapper/normalizer, obsolete layout helper cluster and its self-only tests, and the superseded `RetryAttempt` helper. Reuse hot-zone/divider constants and remove unreachable full-screen ternaries.
- Separate toolbar ownership, AppKit event/delegate bridging, and hover scheduling into their own files. The host remains the only window layout-state owner. Separate the AVFoundation driver from the queue-confined capture state machine for deterministic testing.

### Runtime Acceptance and Limits

The canonical script launched the updated app and a connected iPad Pro (11-inch, M4) displayed changing live content. A temporary unselected window showed the native selection state. Right-click opened `Open in New Window` without selecting the device; after dismissal the window still showed `Select a device`. A normal row click focused the existing device owner. The temporary window was closed afterward, leaving the live capture available.

Native toolbar controls showed/hid the sidebar. The View menu entered and exited full screen; a settled screenshot showed the native toolbar hidden after the pointer entered the preview margin, and exit restored ordinary compact video. Native Zoom enlarged the ordinary preview, and a subsequent sidebar round trip retained an enlarged preview. These are endpoint/interaction observations, not continuous frame-pacing measurements. The computer-use tool required state refreshes around auto-hidden controls and returned one transient ScreenCaptureKit screenshot error during the full-screen transition; the settled state was then observed successfully. A scripted right-edge drag did not establish a changed size, so physical edge-drag acceptance remains incomplete.

Only one capture source was listed at a time. Initial interaction checks used the iPad; after the final relaunch and a discovery change, an iPhone 16 Pro showed live portrait content and proportional window geometry. Controlled equal-ratio two-device switching, rotation, hot unplug/replug, forced interruption, external-screen removal/restoration, and system-wide appearance switching were not performed. Appearance callbacks were checked with AppKit fixtures in both directions. The no-device and failure components compile and retain their descriptions; the live UI check exercised the available-device selection state rather than disconnecting hardware or changing TCC permissions. No performance, native-resolution, sustained-frame-rate, older-macOS, signing-for-distribution, or notarization claim is made.

### Final Automated Validation

| Check | Result |
| --- | --- |
| Full Debug regression after the final code change | Passed: 100 tests, zero failures, zero skips; verified from the xcresult summary. |
| Universal Release build | Passed; `lipo -archs` reports x86_64 and arm64. |
| Release Analyze | Passed; the app builds without testability and the test target is excluded. |
| Python catalog tests | Passed: nine tests. |
| Offline catalog/resource verification | Passed: generated catalog and pinned source checks. |
| Strict recursive Swift-format lint | Passed. |
| Shell, project/plist syntax and Git whitespace | Passed. |
| Strict deep Debug and Release bundle signature verification | Passed; local ad-hoc signatures, not distribution signing. |
| Canonical `./script/build_and_run.sh --verify` | Passed after the final source change; the running app was observed again. |

Initial development builds exposed a missing explicit state initializer and Swift Testing macro restrictions on mutating expressions; both were corrected before tests ran. The focused run passed 26 tests, the first full run passed 99, and the final run passed 100 after adding coverage for non-live resizing during a chrome animation. Those counts are distinct suite iterations, not cumulative coverage. Final build logs contain the expected AppIntents metadata-extraction notice because this app does not link AppIntents; no dependency was added merely to suppress that notice.

Evidence paths:

- `/tmp/USBDisplay-Fixes-Final-20260905.xcresult`
- `/tmp/USBDisplay-Fixes-Final-20260905.log`
- `/tmp/USBDisplay-Fixes-Release-Final-20260905.log`
- `/tmp/USBDisplay-Fixes-Run-Final-20260905.log`

These local artifacts are temporary. Source regressions and this report retain the durable validation record.

Final startup observation: the canonical app launched at 21:18:44, remained visibly connecting, and AVFoundation logged `startRunning` / did-start notification at 21:20:43. Discovery logged one device, then zero at 21:20:46, then one at 21:20:55. The final UI selected an iPhone 16 Pro and displayed live portrait content. The cause of the startup wait was not isolated; neither the subsequent device change nor this endpoint proves a controlled latency/reconnection test. No privacy settings, USB cables, or capture pipeline were changed by the agent to force recovery. A short thread sample was taken after startup had resumed and did not establish the earlier blocking call. This runtime limitation remains explicit in current state.
