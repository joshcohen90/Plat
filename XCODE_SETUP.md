# NextStop — Xcode setup (remaining steps)

The app target already exists. Source files are on disk under `NextStop/`, `NextStopKit/`, `NextStopWidget/`, `Proto/`, `Tools/`. You need to (a) add the source files to the right Xcode targets, (b) add 2 more targets (framework + widget), (c) wire entitlements + capabilities, (d) run two scripts.

Bundle id in this project: `Joshua-Cohen.NextStop`. App Group: `group.Joshua-Cohen.NextStop`. BGTask id: `Joshua-Cohen.NextStop.refresh`. These are already hard-coded in `NextStopKit/Storage/AppGroup.swift` and `NextStop/Background/BackgroundRefresh.swift`.

---

## 1. Add the existing app source to the NextStop target

In Xcode's project navigator, right-click the `NextStop` group → **Add Files to "NextStop"…** → select these folders inside `NextStop/`:

- `Search/`
- `SavedStops/`
- `StopDetail/`
- `Location/`
- `Background/`
- `Resources/` (may be empty until you run the build script — fine)

Settings: **Create groups**, **Copy items if needed: OFF** (they're already there), add to target **NextStop**.

`NextStopApp.swift` and `RootView.swift` at the top of `NextStop/` should already be members of the target — if not, add them too.

## 2. Add the NextStopKit framework target

1. File → New → Target → iOS → **Framework**.
2. Product Name: `NextStopKit`. Embed in Application: NextStop.
3. Delete any auto-generated placeholder files inside the new target's group.
4. Right-click the new `NextStopKit` group → **Add Files to "NextStop"…** → select the `NextStopKit/` folder at the project root. Add to target **NextStopKit only**.
5. NextStop target → General → Frameworks, Libraries, and Embedded Content → confirm `NextStopKit.framework` is **Embed & Sign**.

## 3. Add the NextStopWidget extension target

1. File → New → Target → iOS → **Widget Extension**.
2. Product Name: `NextStopWidget`. **Uncheck** Configuration Intent and Live Activity. Activate the scheme.
3. Delete the template files Xcode generated inside the new `NextStopWidget/` group.
4. Right-click the new `NextStopWidget` group → Add Files → select the existing `NextStopWidget/` folder at project root. Add to target **NextStopWidget only**.
5. NextStopWidget target → General → Frameworks → `+` → `NextStopKit.framework` (**Do Not Embed**; the host app embeds it).

## 4. App Group capability (both targets)

For **NextStop**:
- Signing & Capabilities → `+ Capability` → **App Groups**.
- `+` and add: `group.Joshua-Cohen.NextStop`. Make sure it's checked.

Repeat for **NextStopWidget** with the **same** app group.

## 5. Background Modes & Location (NextStop target)

Signing & Capabilities → `+ Capability` → **Background Modes**. Check:
- [x] Location updates
- [x] Background fetch
- [x] Background processing

Info.plist (NextStop target → Info tab):

| Key | Type | Value |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | String | `NextStop uses your location to show the closest saved transit stops.` |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | String | `Allow background location so your widget stays accurate when you move between neighborhoods.` |
| `BGTaskSchedulerPermittedIdentifiers` | Array of String | one entry: `Joshua-Cohen.NextStop.refresh` |

## 6. Swift Protobuf SPM (NextStopKit only)

1. File → Add Package Dependencies → `https://github.com/apple/swift-protobuf`.
2. Add the `SwiftProtobuf` library to the **NextStopKit** target only.

## 7. Run the build scripts

```bash
brew install protobuf swift-protobuf
cd ~/NextStop
./Tools/gen-proto.sh             # → NextStopKit/Realtime/gtfs_realtime.pb.swift
./Tools/build_stops_json.sh      # → NextStop/Resources/stops.json (subway)
./Tools/build_bus_stops_json.sh  # → NextStop/Resources/bus_stops.json (bus, ~10 min)
```

Drag each output into Xcode after it appears:
- `gtfs_realtime.pb.swift` → NextStopKit target
- `stops.json` and `bus_stops.json` → NextStop target's **Copy Bundle Resources** phase

## 8. Build & run on a real device

Significant location changes and BGTask don't fire reliably in the simulator. Grant location "Always" on first launch so the widget can refresh in the background.
