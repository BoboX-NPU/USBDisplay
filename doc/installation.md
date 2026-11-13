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

The app in **version 1.0.1** is signed with **Developer ID Application: mingbo xue (9PSN33WBG7)** and notarized by Apple. A stapled ticket is included in the app for offline verification. The exported app and copies from both archives passed signature, ticket, and Gatekeeper checks; a quarantined extracted app also passed Apple's distribution checker.

The app is notarized; the DMG is a transport container and is not claimed to have its own separate notarization ticket. Both DMG and ZIP contain the same signed, stapled app.

macOS can still show its normal confirmation that an app was downloaded from the Internet, and the app still needs Camera permission for the device video stream. These are distinct from an unidentified-developer or missing-notarization block. See [Apple's first-launch guidance](https://support.apple.com/en-us/102445).

If you still see a developer-verification error, confirm that you downloaded **1.0.1 or later**, verify the checksum, and replace any older copy in Applications. The original **1.0.0** downloads remain preserved and are ad-hoc signed, without notarization. Do not disable Gatekeeper globally. If macOS reports damage or malware, stop and verify the download instead of bypassing the warning.

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
