# Installing USB Display

## Requirements and downloads

- macOS 14 or later, on Apple Silicon or Intel.
- A USB-connected iPhone or iPad with a data-capable cable.
- An unlocked device and any required trust prompts completed.

Download the DMG or ZIP from [GitHub Releases](https://github.com/BoboX-NPU/USBDisplay/releases). A universal archive contains both Mac architectures. The prebuilt app does not require Xcode, Python, an account, or an app on the phone/tablet.

The deployment target is macOS 14; physical runtime coverage across older macOS versions and Intel machines remains incomplete.

## Installation

1. Open the DMG and drag `USB Display.app` to Applications. Alternatively, unzip the ZIP and move the app into Applications.
2. Open the app. Connect the unlocked mobile device and accept any trust prompts.
3. Allow Camera access when macOS asks. This permission is used for the USB device video stream; the app does not use the Mac camera.
4. Select the device in the sidebar. Use the toolbar to show/hide the sidebar, drag the divider to adjust its width, and use macOS full screen when needed.

## Signing and first launch

Version 1.0.0 has an **ad-hoc signature, no Developer ID Application signature, and no Apple notarization**. A strict local signature check verifies the package's internal integrity but does not make it a trusted/notarized download. macOS Gatekeeper rejected the locally assessed release bundle.

If you trust the source and macOS blocks this app, attempt to open it once, then check **System Settings > Privacy & Security** for **Open Anyway**. Availability depends on the warning and local device-management policy. Follow [Apple's instructions for safely opening apps](https://support.apple.com/en-us/102445). Do not disable Gatekeeper globally. If macOS reports malware or a damaged app, stop and verify the download or build the source instead of treating that as the ordinary unidentified-developer prompt.

The maintainer is tracking Developer ID signing and notarization for a later release. These first-release downloads are intended for users comfortable with the documented trust limitation.

## Verify a download

Download `SHA256SUMS.txt` together with both archives, then run this in that download directory:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

If you downloaded only one archive, compare its `shasum -a 256` result with the matching line in the checksum file. Checksums detect mismatched downloads; they are not a substitute for Developer ID signing or notarization.

## Troubleshooting

| Symptom | Next check |
| --- | --- |
| No device | Unlock it, check trust prompts and cable data support, and reconnect. |
| Connecting for a long time | Check unlock/trust and Camera permission. Restart the app if necessary; startup latency is still being investigated. |
| Permission denied | Enable the app under System Settings > Privacy & Security > Camera, then relaunch. Automatic permission recovery is not yet implemented. |
| Black video | Test ordinary non-DRM content, verify the device is unlocked, and try reconnecting/relaunching. Protected content may stay black. |
| Device already in use | Close another capture application using the same device and retry. |
| Unexpected corners or unresolved model | Unknown or ambiguous devices use a conservative fallback. Report the model and OS versions without sharing unique identifiers. |

For a reproducible problem, use the [bug report form](https://github.com/BoboX-NPU/USBDisplay/issues/new?template=bug_report.yml) and include app/macOS/device versions, steps, expected behavior, and actual behavior. Redact personal device names and screen content.

## Updating and removal

There is no built-in updater in 1.0.0. Download a newer GitHub release, quit the app, and replace it in Applications. Keep the new release's signing/installation notes in mind. To remove the app, quit it and move `USB Display.app` from Applications to Trash.
