#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --github ) ]]; then
  echo "usage: $0 [--github]" >&2
  echo "Build ad-hoc-signed DMG/ZIP packages; --github uses public download names." >&2
  exit 2
fi
PACKAGE_MODE="${1:-local}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/Xcode"
APP_NAME="USB Display"
APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"

verify_architectures() {
  local actual required
  actual=$(xcrun lipo -archs "$1")
  for required in arm64 x86_64; do
    if [[ " $actual " != *" $required "* ]]; then
      echo "Missing $required architecture: $1" >&2
      return 1
    fi
  done
}

xcodebuild \
  -project "$ROOT_DIR/USBDisplay.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build

codesign --verify --deep --strict "$APP_BUNDLE"
verify_architectures "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")
PACKAGE_NAME="USBDisplay-$VERSION-build$BUILD-local"
if [[ "$PACKAGE_MODE" == --github ]]; then
  PACKAGE_NAME="USBDisplay-$VERSION-macOS-universal"
fi
mkdir -p "$ROOT_DIR/.build/Distribution"
PACKAGE_DIR=$(mktemp -d "$ROOT_DIR/.build/Distribution/$PACKAGE_NAME.XXXXXX")
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/usb-display-package.XXXXXX")
MOUNT_DIR="$STAGING_DIR/mounted"
IMAGE_MOUNTED=false
cleanup() {
  if [[ "$IMAGE_MOUNTED" == true ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null || true
  fi
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir "$STAGING_DIR/image" "$MOUNT_DIR" "$STAGING_DIR/unzipped"
ditto "$APP_BUNDLE" "$STAGING_DIR/image/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/image/Applications"
cat > "$STAGING_DIR/image/Read Me.txt" <<'EOF'
USB Display - Ad-hoc-signed Release

Install: drag USB Display.app to Applications, then open it.
Requires macOS 14 or later. Includes Apple Silicon and Intel executables.
Connect an unlocked iPhone or iPad by USB and complete any trust prompts.
Allow video capture access when macOS asks; the app uses it for the USB screen stream.

This package is ad-hoc signed, has no Developer ID Application signature,
and is not notarized by Apple. macOS may block the initial launch.
Read the installation and trust guidance before opening it:
https://github.com/BoboX-NPU/USBDisplay/blob/main/doc/installation.md

Source, license, release notes, and downloads:
https://github.com/BoboX-NPU/USBDisplay

Older macOS/Intel runtime coverage, continuous dragging, prolonged capture,
and startup/black-preview behavior still need broader verification.
The app contains its MIT license and third-party notices in Contents/Resources.
EOF

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PACKAGE_DIR/$PACKAGE_NAME.zip"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR/image" \
  -fs HFS+ -format UDZO "$PACKAGE_DIR/$PACKAGE_NAME.dmg"
hdiutil verify "$PACKAGE_DIR/$PACKAGE_NAME.dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$PACKAGE_DIR/$PACKAGE_NAME.dmg"
IMAGE_MOUNTED=true
codesign --verify --deep --strict "$MOUNT_DIR/$APP_NAME.app"
verify_architectures "$MOUNT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
hdiutil detach "$MOUNT_DIR"
IMAGE_MOUNTED=false

ditto -x -k "$PACKAGE_DIR/$PACKAGE_NAME.zip" "$STAGING_DIR/unzipped"
codesign --verify --deep --strict "$STAGING_DIR/unzipped/$APP_NAME.app"
codesign -d --verbose=4 "$APP_BUNDLE" > "$PACKAGE_DIR/signature.txt" 2>&1
codesign -d --entitlements :- "$APP_BUNDLE" > "$PACKAGE_DIR/entitlements.plist" 2>/dev/null
ditto "$STAGING_DIR/image/Read Me.txt" "$PACKAGE_DIR/Read Me.txt"
(
  cd "$PACKAGE_DIR"
  shasum -a 256 "$PACKAGE_NAME.dmg" "$PACKAGE_NAME.zip" > SHA256SUMS.txt
)
printf '\nRelease packages: %s\n' "$PACKAGE_DIR"
