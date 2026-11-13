# Developer ID signing and notarization

Public downloads starting with 1.0.1 contain a Developer ID-signed app that has been notarized by Apple and includes a stapled ticket. Local Debug and ad-hoc packaging workflows remain available for contributors.

## Prerequisites

- A full Xcode installation, an authenticated Apple Developer Program account in Xcode, and permission to distribute with the selected team.
- Access to a Developer ID Application signing certificate through Xcode's distribution workflow. An Apple Distribution certificate is not a substitute.
- The release version/build already set in both app configurations, and a clean, reviewed source tree for the final source tag.

The verified 1.0.1 workflow used Xcode 27.2 and team `9PSN33WBG7`. Automatic Developer ID export signed the app as `Developer ID Application: mingbo xue (9PSN33WBG7)` with certificate SHA-1 `CFBE77C410EBBDBC13DD2C63892651A6B0EFA160`. The local `security find-identity` inventory still listed only the pre-existing development/distribution identities afterward; the successful export does not establish that a new Developer ID private key is installed locally. Do not export credentials or assume a locally usable identity exists merely because Xcode can sign the archive.

No app-specific password or App Store Connect private API key was added to this repository or required for this run. Xcode used its existing authenticated account. Treat future account/certificate creation prompts as explicit security actions; never revoke an existing certificate to troubleshoot an export casually.

## Archive and submit

Create a unique temporary working directory and keep its path until notarized export and packaging are complete:

```bash
NOTARY_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/usb-display-notary.XXXXXX")
DEVELOPER_TEAM_ID=9PSN33WBG7

xcodebuild \
  -project USBDisplay.xcodeproj \
  -scheme 'USB Display' \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$PWD/.build/Xcode" \
  -archivePath "$NOTARY_WORK_DIR/USB Display.xcarchive" \
  ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM="$DEVELOPER_TEAM_ID" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENABLE_HARDENED_RUNTIME=YES \
  archive
```

The intermediate archive is ad-hoc signed. The following export step applies Developer ID signing before submitting to Apple. Save this non-secret export configuration as `$NOTARY_WORK_DIR/ExportOptions.plist`, substituting your authorized team when applicable:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>9PSN33WBG7</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath "$NOTARY_WORK_DIR/USB Display.xcarchive" \
  -exportPath "$NOTARY_WORK_DIR/Upload" \
  -exportOptionsPlist "$NOTARY_WORK_DIR/ExportOptions.plist" \
  -allowProvisioningUpdates
```

`EXPORT SUCCEEDED` for the upload only establishes submission, not acceptance. If the command reports a failure, inspect the error before retrying. Do not repeatedly submit the same archive while an existing submission is still processing.

## Retrieve the notarized app

After Apple has processed the submission:

```bash
xcodebuild -exportNotarizedApp \
  -archivePath "$NOTARY_WORK_DIR/USB Display.xcarchive" \
  -exportPath "$NOTARY_WORK_DIR/Notarized"
```

If processing is incomplete, keep the same archive and retry the retrieval after checking its status; do not rebuild or re-upload unnecessarily. Xcode Organizer also exposes the Developer ID status and Export Notarized App action.

Validate the exported app before packaging:

```bash
codesign --verify --deep --strict "$NOTARY_WORK_DIR/Notarized/USB Display.app"
codesign -d --verbose=4 "$NOTARY_WORK_DIR/Notarized/USB Display.app"
xcrun stapler validate "$NOTARY_WORK_DIR/Notarized/USB Display.app"
spctl --assess --type execute --verbose=4 "$NOTARY_WORK_DIR/Notarized/USB Display.app"
```

Require a Developer ID Application authority, the expected team and version, hardened runtime, the camera entitlement without debugging entitlements, a valid stapled ticket, and Gatekeeper acceptance with `source=Notarized Developer ID`. Archive metadata can retain a stale processing label; successful ticket and Gatekeeper checks establish the exported artifact's state.

## Package and verify

```bash
./script/package_local_release.sh \
  --notarized-app "$NOTARY_WORK_DIR/Notarized/USB Display.app"
```

This mode packages the supplied app without rebuilding or re-signing it. It requires Developer ID signature validation, a valid stapled ticket, and Gatekeeper acceptance, then repeats those checks on the mounted-DMG and extracted-ZIP apps. Archives, checksums, signature/entitlement records, and bilingual installation notes are retained under `.build/Distribution`.

The app has the notarization ticket. ZIP cannot be stapled; the stapled app must be inside the ZIP. The DMG is a transport container and is not claimed to have a separate notarization ticket. Do not describe the entire disk image as notarized unless it has independently been submitted and stapled.

Verify final downloads, including an extracted temporary app with a download quarantine attribute, using Gatekeeper and `xcrun syspolicy_check distribution` on a host that provides it. Validate the final checksum file and preserve results in the development log. This does not replace physical capture/older-OS acceptance, and normal first-launch confirmation and Camera permission prompts can remain.

After exported downloads and checks are complete, remove the task's temporary archive, exports, and logs. Keep release assets and concise verification records. Follow the [release procedure](releases.md) to publish a new patch version; never replace previously published binaries silently.

## References

- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Upload a macOS app to be notarized](https://help.apple.com/xcode/mac/current/en.lproj/dev88332a81e.html)
- [Apple: Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
