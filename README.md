# USB Display

<img src="doc/design/usb-display-icon-composer-preview.png" alt="USB Display app icon" width="128">

A native macOS app for displaying a USB-connected iPhone or iPad in a resizable window. Built with SwiftUI, AppKit, and AVFoundation. No companion app or account is required.

## Download

**[Download v1.0.0 for macOS — DMG](https://github.com/BoboX-NPU/USBDisplay/releases/download/v1.0.0/USBDisplay-1.0.0-macOS-universal.dmg)**

[ZIP download](https://github.com/BoboX-NPU/USBDisplay/releases/download/v1.0.0/USBDisplay-1.0.0-macOS-universal.zip) · [Checksums](https://github.com/BoboX-NPU/USBDisplay/releases/download/v1.0.0/SHA256SUMS.txt) · [Release notes and all versions](https://github.com/BoboX-NPU/USBDisplay/releases)

Requires **macOS 14 or later** and a USB data cable. The same download includes Apple Silicon and Intel executables. Xcode is only needed to build from source.

**Signing status:** v1.0.0 is ad-hoc signed and **not notarized by Apple**. macOS may block the initial launch. Read the [installation and trust instructions](doc/installation.md) before downloading. Older macOS and Intel runtime coverage is still incomplete; the minimum deployment target is not a claim that every configuration has been physically tested.

## What it does

- Displays a wired iPhone or iPad screen with proportional resizing and full-screen viewing.
- Keeps separate windows and capture sessions for selected devices.
- Offers a resizable device sidebar and compact controls that appear on hover.
- Resolves device models and applies display-corner profiles from a bundled catalog.
- Shows connection, unlock/trust, permission, and interruption states.

The app displays video locally. It does not record, capture audio, transmit the screen remotely, or control the iPhone/iPad. DRM-protected content may appear black. USB capture is provided by the operating system, and availability can vary by device and software version.

## Get started

1. Install `USB Display.app` from the DMG or ZIP.
2. Connect an unlocked iPhone or iPad with a USB data cable and accept any trust prompts.
3. Open the app and allow Camera access when macOS requests it. AVFoundation uses this permission for the device's video stream; the app does not use the Mac camera.
4. Select the device in the sidebar. Use its context menu to open an unclaimed device in another window.

See [installation and troubleshooting](doc/installation.md) for blocked launches, missing devices, black screens, and permissions.

## Build and test

The current source and layered icon are validated with **Xcode 27.2**. Select a full Xcode installation before building; older toolchains have not been validated for this source revision.

```bash
git clone https://github.com/BoboX-NPU/USBDisplay.git
cd USBDisplay
./script/build_and_run.sh --verify
```

Run the application tests and offline catalog checks:

```bash
./script/test.sh
PYTHONDONTWRITEBYTECODE=1 python3 script/test_device_profiles.py
PYTHONDONTWRITEBYTECODE=1 python3 script/update_device_profiles.py --check
```

Tests use a disposable build directory and clean it up after completion or normal interruption. The canonical app build stays in `.build/Xcode`; release packages stay in `.build/Distribution`. See [CONTRIBUTING.md](CONTRIBUTING.md) for filters, validation, and the contribution workflow. Automated hosted CI is a tracked follow-up; local test results are not a GitHub Actions status.

## Project layout

| Path | Responsibility |
| --- | --- |
| `USBDisplay/App/` | Application and scene entrypoint |
| `USBDisplay/Models/` | Device, connection, geometry, and resize policies |
| `USBDisplay/Services/` | Discovery, capture state, and read-only USB identification |
| `USBDisplay/Views/` | SwiftUI screens, AppKit hosting, toolbar, and window interaction |
| `USBDisplay/Resources/` | Shipping icon, device catalog, and third-party notices |
| `USBDisplayTests/` | Capture, identity, layout, and rendering regressions |
| `Config/`, `USBDisplay.xcodeproj/` | Bundle metadata, entitlements, and build configuration |
| `script/`, `data/device-profiles/` | Development tools and pinned catalog inputs |
| `doc/`, `.github/` | User/maintainer documentation and contribution templates |

Keep runtime features in these existing layers. Introduce a new module only when it has a clear boundary and its own useful tests.

## Contribute and follow development

- [Report a bug or propose a feature](https://github.com/BoboX-NPU/USBDisplay/issues/new/choose).
- Read the [contribution guide](CONTRIBUTING.md), [roadmap](doc/roadmap.md), and [changelog](CHANGELOG.md).
- Maintainer planning lives in a separate Linear project; public contributions go through GitHub and do not require a Linear account.
- Detailed architecture and verification limits are in [current project state](doc/current.md). [Release procedure](doc/releases.md) and [development history](doc/devlog.md) describe how changes become releases.

## License and acknowledgements

[MIT](LICENSE). Device metadata includes pinned DeviceKit and BezelKit data with their own preserved [notices](USBDisplay/Resources/ThirdPartyNotices.txt). See the [catalog provenance](doc/device-corner-profiles.md) for sources, reviewed conflicts, and validation limits. This project is independent of Apple.
