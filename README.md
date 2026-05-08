# Plat

iOS app that shows the next train arrivals at the 3 closest of your saved MTA subway stops, on a Home Screen and Lock Screen widget. Background location updates the "closest 3" as you move.

## Status (v1, scaffolded)

- ✅ Phase 1: Models, App Group storage, static stop catalog + build script, SwiftUI add-stop flow (line → stop → direction), saved stops list
- ✅ Phase 2: GTFS-Realtime client (Swift Protobuf), feed routing per line group, in-app arrivals view
- ✅ Phase 3: Significant-change location, RefreshCoordinator, BGAppRefreshTask
- ✅ Phase 4: Home Screen medium widget + Lock Screen rectangular & inline
- ⏸ Phase 5 (deferred): Bus / SIRI

## First-run

1. Open `XCODE_SETUP.md` and follow it end-to-end (creates targets, App Group, entitlements, adds Swift Protobuf SPM).
2. `./Tools/gen-proto.sh` — generates `PlatKit/Realtime/gtfs_realtime.pb.swift`.
3. `./Tools/build_stops_json.sh` — derives `Plat/Resources/stops.json` from MTA static GTFS.
4. Build & run on device (widget won't fully exercise in simulator — background location and BGTask only fire on hardware).

## Architecture

- `PlatKit/` (framework, shared with widget)
  - `Models/` `TransitStop`, `SavedStop`, `Arrival`, `WidgetSnapshot`
  - `Storage/` `AppGroup` (suite identifier + container URL), `SavedStopsStore`, `SnapshotStore`
  - `Realtime/` `FeedRouter` (line→feed URL), `GTFSRealtimeClient` (protobuf decode + cache), `ArrivalsService` (per-stop filtering, parallel feed fetch)
  - `Geo/` `Closest` (3-nearest computation)
  - `StaticData/` `StopCatalog` (loads bundled `stops.json`, fallback seed)
- `Plat/` (app)
  - `Search/` line list → stop list → direction picker
  - `SavedStops/` list with distance + swipe-to-delete
  - `StopDetail/` per-stop arrivals view (used in-app, not in widget)
  - `Location/` `LocationManager` (significant-change CL)
  - `Background/` `RefreshCoordinator` (the pipeline), `BackgroundRefresh` (BGTask scheduling)
- `PlatWidget/`
  - `Provider` (TimelineProvider reading the snapshot from the App Group)
  - `NearbyStopsWidget` (medium / large)
  - `LockScreenWidget` (rectangular / inline)

## Refresh trigger sources (all funnel into `RefreshCoordinator.refresh`)

- App launch / foreground
- Significant location change
- Pull-to-refresh on saved stops list
- Saved stops added / removed
- BGAppRefreshTask (every ~15 min when iOS allows)

The coordinator: computes 3 closest → fetches each line's feed once (in parallel, cached 45s) → writes a `WidgetSnapshot` to App Group UserDefaults → `WidgetCenter.reloadAllTimelines()`.

## Known caveats / things you'll want to address

- **Bus support is not in v1.** SIRI feeds need a bustime.mta.info API key.
- **Direction labels are hard-coded** per line because GTFS encodes it as just N/S in the stop_id suffix. The labels aren't always right at every station (e.g. branched lines like the 5).
- **Background refresh budget is set by iOS**, not us. Don't expect 15-min cadence reliably — Apple decides based on app usage patterns.
- **Widget reload policy** is opportunistic: the next reload date is set 30s before the next visible arrival. iOS may delay it. The widget shows the *snapshot* the app last wrote; it doesn't fetch on its own (widget extensions can't easily make network calls within budget for our 3-feed fan-out).
- The widget therefore depends on the app having run (foreground or background) within roughly the last 5–10 minutes. That's fine for commute use; less fine if you open it for the first time after a 12-hour idle.
- The MTA endpoint URLs in `FeedRouter.swift` are best-known as of late 2025 — if MTA changes hosts, update there.
