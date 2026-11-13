#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/Xcode"
APP_NAME="USB Display"
APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"
PACKAGE_MODE="${1:-local}"
REQUIRE_NOTARIZATION=false

if [[ $# -eq 2 && "${1:-}" == --notarized-app ]]; then
  APP_BUNDLE="$(cd "$2" && pwd)"
  PACKAGE_MODE=--github
  REQUIRE_NOTARIZATION=true
elif [[ $# -gt 1 || ( $# -eq 1 && "$1" != --github ) ]]; then
  echo "usage: $0 [--github | --notarized-app /path/to/USB\ Display.app]" >&2
  echo "Build local ad-hoc packages, or package an already signed, notarized, stapled app." >&2
  exit 2
fi

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

verify_app() {
  codesign --verify --deep --strict "$1"
  verify_architectures "$1/Contents/MacOS/$APP_NAME"
  if [[ "$REQUIRE_NOTARIZATION" == true ]]; then
    codesign --verify --strict \
      -R='anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$1"
    xcrun stapler validate "$1"
    spctl --assess --type execute --verbose=4 "$1"
  fi
}

if [[ "$REQUIRE_NOTARIZATION" == false ]]; then
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
fi

verify_app "$APP_BUNDLE"
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
PACKAGE_COMPLETE=false
cleanup() {
  if [[ "$IMAGE_MOUNTED" == true ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null || true
  fi
  rm -rf "$STAGING_DIR"
  if [[ "$PACKAGE_COMPLETE" == false ]]; then
    rm -rf "$PACKAGE_DIR"
  fi
}
trap cleanup EXIT

# Isolate release-only Python dependencies and remove them with staging. An
# explicitly supplied interpreter can reuse an already prepared tool environment.
DMG_PYTHON="${DMGBUILD_PYTHON:-}"
if [[ -z "$DMG_PYTHON" ]]; then
  python3 -m venv "$STAGING_DIR/dmg-tools"
  DMG_PYTHON="$STAGING_DIR/dmg-tools/bin/python"
  "$DMG_PYTHON" -m pip --isolated install --disable-pip-version-check --no-cache-dir \
    --index-url https://pypi.org/simple --only-binary=:all: --require-hashes \
    -r "$ROOT_DIR/script/requirements-dmg.txt"
fi

mkdir "$STAGING_DIR/image" "$MOUNT_DIR" "$STAGING_DIR/unzipped"
ditto "$APP_BUNDLE" "$STAGING_DIR/image/$APP_NAME.app"
if [[ "$REQUIRE_NOTARIZATION" == true ]]; then
  cat > "$STAGING_DIR/image/Read Me.txt" <<'EOF'
USB Display

简体中文

安装：将 USB Display.app 拖到“应用程序”，然后打开。
需要 macOS 14 或更新版本，支持 Apple Silicon 和 Intel。
连接已解锁的 iPhone/iPad，完成信任提示，并允许读取设备视频流所需的“相机”权限。

此安装包内的应用已使用 Developer ID 签名、通过 Apple 公证，并附带离线公证票据。
首次打开仍可能显示正常的互联网下载确认和相机权限提示。
版本说明、系统兼容性和已知限制见下方项目地址。

English

Install: drag USB Display.app to Applications, then open it.
Requires macOS 14 or later. Includes Apple Silicon and Intel executables.
Connect an unlocked iPhone or iPad, complete trust prompts, and allow video capture access.

The app inside this package is Developer ID signed, notarized by Apple,
and includes a stapled ticket for offline verification. Normal first-launch
download confirmation and Camera permission prompts can still appear.
See the project for compatibility coverage, known limits, and release notes.

https://github.com/BoboX-NPU/USBDisplay
https://github.com/BoboX-NPU/USBDisplay/releases

The app contains its MIT license and third-party notices in Contents/Resources.
EOF
else
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
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PACKAGE_DIR/$PACKAGE_NAME.zip"
"$DMG_PYTHON" -m dmgbuild \
  -s "$ROOT_DIR/script/dmg_settings.py" \
  -D "app=$STAGING_DIR/image/$APP_NAME.app" \
  -D "artwork=$ROOT_DIR/Packaging/DMG" \
  "$APP_NAME" "$PACKAGE_DIR/$PACKAGE_NAME.dmg"
hdiutil verify "$PACKAGE_DIR/$PACKAGE_NAME.dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$PACKAGE_DIR/$PACKAGE_NAME.dmg"
IMAGE_MOUNTED=true
verify_app "$MOUNT_DIR/$APP_NAME.app"
[[ -L "$MOUNT_DIR/Applications" && "$(readlink "$MOUNT_DIR/Applications")" == /Applications ]]
[[ -s "$MOUNT_DIR/.DS_Store" && -s "$MOUNT_DIR/.background.tiff" ]]
hdiutil detach "$MOUNT_DIR"
IMAGE_MOUNTED=false

ditto -x -k "$PACKAGE_DIR/$PACKAGE_NAME.zip" "$STAGING_DIR/unzipped"
verify_app "$STAGING_DIR/unzipped/$APP_NAME.app"
codesign -d --verbose=4 "$APP_BUNDLE" > "$PACKAGE_DIR/signature.txt" 2>&1
codesign -d --entitlements :- "$APP_BUNDLE" > "$PACKAGE_DIR/entitlements.plist" 2>/dev/null
ditto "$STAGING_DIR/image/Read Me.txt" "$PACKAGE_DIR/Read Me.txt"
(
  cd "$PACKAGE_DIR"
  shasum -a 256 "$PACKAGE_NAME.dmg" "$PACKAGE_NAME.zip" > SHA256SUMS.txt
)
PACKAGE_COMPLETE=true
printf '\nRelease packages: %s\n' "$PACKAGE_DIR"
