# Layered USB Display App Icon

The shipping source is [`AppIcon.icon`](../../USBDisplay/Resources/AppIcon.icon), an editable Apple Icon Composer document. Open it with the Icon Composer included in Xcode. The [default preview](usb-display-icon-composer-preview.png) was rendered with Apple's `ictool` using design generation 27.

## Composition

- Use a 1024-by-1024 canvas with a white default background, blue-gray enclosures, and pale-blue displays.
- Align both device enclosures at `y = 816`. The iPad occupies `(206, 184, 464, 632)` and the iPhone occupies `(592, 336, 262, 480)`, expressed as `(x, y, width, height)`.
- Balance the combined visual weight around the canvas center while preserving the iPhone's foreground overlap. The unequal device sizes call for optical placement rather than centering each device separately.
- Preserve the iPhone Dynamic Island and both home indicators. Their Liquid Glass effects are disabled to keep the small details crisp.

## Layers and Materials

The document contains six SVG images in four depth groups, listed here from back to front:

1. iPad enclosure.
2. iPad display and home indicator.
3. iPhone enclosure.
4. iPhone display, Dynamic Island, and home indicator.

The JSON lists foreground groups and layers first. Each SVG uses the complete 1024-pixel canvas, so placement remains consistent on import. Source images contain only flat, opaque vector rectangles with rounded corners. They do not contain a background, system icon mask, raster images, gradients, shadows, or highlights.

Icon Composer supplies the background, system mask, lighting, shadows, and Liquid Glass effects. Each group uses 15% translucency to retain some material depth while keeping the overlapping device silhouettes clear. Default, dark, clear, and tinted appearances use the native renderer's adaptation. Appearance and highlight treatments differ between system generations.

## Build and Export

Both app configurations select `AppIcon`, and the Xcode resource phase includes the `.icon` document with the `folder.iconcomposer.icon` file type. Xcode compiles its layered resources and generates compatible icon images for the app's macOS 14 minimum deployment target. Runtime acceptance on older systems is still required.

Run `./script/export_app_icon.sh` to export the six generation-27 appearance previews and a generation-26 default preview into `.build/IconPreviews`. An optional first argument selects a different output directory. This script uses the Icon Composer bundled with the selected Xcode installation; these preview PNGs are not the shipping icon source.

The earlier v8 SVG, its raster preview, and `Assets.xcassets/AppIcon.appiconset` remain as historical flat artwork. Xcode's native `.icon` document takes precedence over the matching legacy asset catalog. `script/generate_app_icon.swift` only regenerates that historical bitmap catalog.

## Apple References

- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer): layered SVG preparation, four depth groups, native effects, appearance previews, Xcode integration, and older-system image generation.
- [Human Interface Guidelines: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons): foreground clarity, optical composition, system masking, and adaptive icon materials.
- [Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/): native material workflow and keeping small details readable.

Implementation was checked against the installed Xcode 27.2 documentation and the current Apple documentation on 2026-11-13. Icon Composer and `ictool` are version 27.2 (build 143). No icon-specific Apple-exported skill was available; the Apple documentation and macOS build/run workflow were used.
