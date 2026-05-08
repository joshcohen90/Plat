# Plat — Xcode setup (remaining steps)

The app target already exists. Source files are on disk under `Plat/`, `PlatKit/`, `PlatWidget/`, `Proto/`, `Tools/`. You need to (a) add the source files to the right Xcode targets, (b) add 2 more targets (framework + widget), (c) wire entitlements + capabilities, (d) run two scripts.

Bundle id in this project: `Joshua-Cohen.Plat`. App Group: `group.Joshua-Cohen.Plat`. BGTask id: `Joshua-Cohen.Plat.refresh`. These are already hard-coded in `PlatKit/Storage/AppGroup.swift` and `Plat/Background/BackgroundRefresh.swift`.

---

## 1. Add the existing app source to the Plat target

In Xcode's project navigator, right-click the `Plat` group → **Add Files to "Plat"…** → select these folders inside `Plat/`:

- `Search/`
- `SavedStops/`
- `StopDetail/`
- `Location/`
- `Background/`
- `Resources/` (may be empty until you run the build script — fine)

Settings: **Create groups**, **Copy items if needed: OFF** (they're already there), add to target **Plat**.

`PlatApp.swift` and `RootView.swift` at the top of `Plat/` should already be members of the target — if not, add them too.

## 2. Add the PlatKit framework target

1. File → New → Target → iOS → **Framework**.
2. Product Name: `PlatKit`. Embed in Application: Plat.
3. Delete any auto-generated placeholder files inside the new target's group.
4. Right-click the new `PlatKit` group → **Add Files to "Plat"…** → select the `PlatKit/` folder at the project root. Add to target **PlatKit only**.
5. Plat target → General → Frameworks, Libraries, and Embedded Content → confirm `PlatKit.framework` is **Embed & Sign**.

## 3. Add the PlatWidget extension target

1. File → New → Target → iOS → **Widget Extension**.
2. Product Name: `PlatWidget`. **Uncheck** Configuration Intent and Live Activity. Activate the scheme.
3. Delete the template files Xcode generated inside the new `PlatWidget/` group.
4. Right-click the new `PlatWidget` group → Add Files → select the existing `PlatWidget/` folder at project root. Add to target **PlatWidget only**.
5. PlatWidget target → General → Frameworks → `+` → `PlatKit.framework` (**Do Not Embed**; the host app embeds it).

## 4. App Group capability (both targets)

For **Plat**:
- Signing & Capabilities → `+ Capability` → **App Groups**.
- `+` and add: `group.Joshua-Cohen.Plat`. Make sure it's checked.

Repeat for **PlatWidget** with the **same** app group.

## 5. Background Modes & Location (Plat target)

Signing & Capabilities → `+ Capability` → **Background Modes**. Check:
- [x] Location updates
- [x] Background fetch
- [x] Background processing

Info.plist (Plat target → Info tab):

| Key | Type | Value |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | String | `Plat uses your location to show the closest saved transit stops.` |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | String | `Allow background location so your widget stays accurate when you move between neighborhoods.` |
| `BGTaskSchedulerPermittedIdentifiers` | Array of String | one entry: `Joshua-Cohen.Plat.refresh` |

## 6. Swift Protobuf SPM (PlatKit only)

1. File → Add Package Dependencies → `https://github.com/apple/swift-protobuf`.
2. Add the `SwiftProtobuf` library to the **PlatKit** target only.

## 7. Run the build scripts

```bash
brew install protobuf swift-protobuf
cd ~/Plat
./Tools/gen-proto.sh             # → PlatKit/Realtime/gtfs_realtime.pb.swift
./Tools/build_stops_json.sh      # → Plat/Resources/stops.json (subway)
./Tools/build_bus_stops_json.sh  # → Plat/Resources/bus_stops.json (bus, ~10 min)
```

Drag each output into Xcode after it appears:
- `gtfs_realtime.pb.swift` → PlatKit target
- `stops.json` and `bus_stops.json` → Plat target's **Copy Bundle Resources** phase

## 8. Build & run on a real device

Significant location changes and BGTask don't fire reliably in the simulator. Grant location "Always" on first launch so the widget can refresh in the background.
