# Read-only USB Device Identification

AVFoundation identifies the currently connected iPhone screen source with the generic capture `modelID` `iOS Device`. Its capture identifier is not a USB serial number. The app retains that capture identity for session routing and obtains the product model separately.

## Protocol Boundary

`USBDeviceInfoClient` implements a small, independent client of the local `/var/run/usbmuxd` Unix socket. Protocol references are the upstream [libusbmuxd implementation](https://github.com/libimobiledevice/libusbmuxd/blob/master/src/libusbmuxd.c) and [libimobiledevice lockdownd implementation](https://github.com/libimobiledevice/libimobiledevice/blob/master/src/lockdown.c). No upstream library is bundled or required.

1. Send the plist `ListDevices` request and retain entries whose `ConnectionType` is `USB`.
2. Open a separate connection for each listed device and send `Connect` to network-byte-order port 62078.
3. After a successful mux response, send length-prefixed lockdownd `GetValue` requests for `ProductType` and `DeviceName` only.
4. Close all connections after the snapshot, on cancellation, or on error.

The mux header has four little-endian 32-bit words: total length, version 1, plist message type 8, and request tag. The lockdownd tunnel uses a big-endian 32-bit plist-body length. Responses must have valid framing and a matching tag/request. Bodies are limited to 1 MiB, lists to 64 entries, and string values to 1 KiB. Partial reads and writes are supported. A four-second monotonic deadline covers the entire snapshot; nonblocking polling checks cancellation at most every 50 ms.

The client does not pair/unpair devices, alter trust, read pairing records, start authenticated sessions, query other keys, install a companion app, or connect to an external network service. It does not depend on Xcode, CoreSimulator, or private Apple frameworks. These protocols are not an Apple-guaranteed public SDK and may change with macOS/iOS releases. Failure leaves video capture independent and the model explicitly unresolved.

## Association and Lifecycle

The catalog refreshes identity asynchronously after capture discovery/connection changes and every five seconds while devices remain present. A generation guard rejects results from replaced snapshots, even if a query completes after cancellation. Disconnecting all capture devices cancels the pending query and retry loop.

A capture device can match a USB identity only when its exact device name occurs once in both complete snapshots. Duplicate names on either side are ambiguous. Enumeration order, aspect ratio, name contents such as “Pro,” and generic capture model strings never imply a product model. A partially unreadable USB snapshot cannot establish uniqueness, so the query fails conservatively instead of applying a possibly wrong profile. Identifiers and USB serial numbers are not logged or persisted by this service.

## Corner Resolution

The exact `ProductType` selects the checked-in [display reference table](device-corner-profiles.md). Radius is the reference logical-point radius divided by the logical screen short side, multiplied by the displayed short side. Rotation uses the same normalized value. The current physical iPhone resolves to `iPhone17,1`, iPhone 16 Pro.

An unlisted product retains its identified model code but uses zero custom radius. Unavailable or ambiguous identities also use zero and show their status in the device row. The manual adjustment panel is removed. The old `displayCornerRadiusOverrides` preference data remains untouched and has no effect on rendering.

## Validation Boundary

Protocol fixtures cover iPhone 16 Pro, iPhone 17 Pro, and iPhone 17 Pro Max values and reference mappings, duplicate names, unknown products, malformed and oversized frames, fragmented Unix-socket responses, timeouts, cancellation, disconnected sockets, and stale publications. Only the connected iPhone 16 Pro has been checked with physical hardware. Protocol fixtures do not constitute physical validation of the other products or of unplug/replug behavior.
