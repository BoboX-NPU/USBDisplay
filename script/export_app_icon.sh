#!/usr/bin/env bash
set -euo pipefail

# Export previews from the native layered document; Xcode builds shipping icons.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_PATH="$(xcode-select -p)"
ICON_TOOL="$DEVELOPER_PATH/../Applications/Icon Composer.app/Contents/Executables/ictool"
ICON_DOCUMENT="$ROOT_DIR/USBDisplay/Resources/AppIcon.icon"
OUTPUT_DIR="${1:-$ROOT_DIR/.build/IconPreviews}"

if [[ ! -x "$ICON_TOOL" ]]; then
  echo "Icon Composer is required in the selected Xcode installation." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

for rendition in Default Dark ClearLight ClearDark TintedLight TintedDark; do
  "$ICON_TOOL" "$ICON_DOCUMENT" --export-image \
    --output-file "$OUTPUT_DIR/$rendition.png" \
    --platform macOS --rendition "$rendition" \
    --width 1024 --height 1024 --scale 1 --design-generation 27
done

"$ICON_TOOL" "$ICON_DOCUMENT" --export-image \
  --output-file "$OUTPUT_DIR/Default-26.png" \
  --platform macOS --rendition Default \
  --width 1024 --height 1024 --scale 1 --design-generation 26

echo "Exported Icon Composer previews to $OUTPUT_DIR"
