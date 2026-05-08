import Foundation
import CoreLocation

/// Refresher used by the widget intent.
///
/// Reads CoreLocation's *cached* last fix (no new fix is requested — that's
/// the app's job) and ranks all saved groups by current distance. This fixes
/// two prior bugs:
///
///   1. Stale ordering: prior snapshot's distances froze whichever 3 were
///      closest at the moment the snapshot was last written, so widget
///      refreshes after a user moved kept the wrong 3.
///   2. New-stop drift: groups not present in the prior snapshot were
///      written with distance=0, then on the *next* refresh that 0 made
///      them sort first, jumping to the top of the widget.
///
/// Falls back to the prior-distance approach only if CL has no cached fix
/// (e.g. user denied location entirely).
public enum SnapshotRefresher {
    @discardableResult
    public static func refreshFromPrior(limit: Int = 3) async -> WidgetSnapshot {
        let saved = SavedStopsStore.shared.stops
        guard !saved.isEmpty else {
            let empty = WidgetSnapshot(generatedAt: .now, groups: [])
            SnapshotStore.write(empty)
            return empty
        }

        let groups = ResolvedGroup.resolve(from: saved)

        // Reading `.location` does NOT trigger a fix — it returns whatever
        // CL most recently captured for this app (foreground use,
        // significant-change wakeup, etc.). Available in the widget
        // extension as long as the user has granted location auth.
        let cachedLoc = CLLocationManager().location

        let sortedWithDistance: [(group: ResolvedGroup, meters: Double)]
        if let here = cachedLoc {
            sortedWithDistance = groups
                .map { g in
                    let d = here.distance(from: CLLocation(
                        latitude: g.coordinate.latitude,
                        longitude: g.coordinate.longitude))
                    return (g, d)
                }
                .sorted { $0.1 < $1.1 }
        } else {
            // No CL cache (location denied / never authorized). Fall back
            // to prior snapshot's distances, then saved order for groups
            // we have no prior data on.
            let priorDistances = SnapshotStore.read()
                .map { Dictionary(uniqueKeysWithValues: $0.groups.map { ($0.groupID, $0.distanceMeters) }) }
                ?? [:]
            sortedWithDistance = groups
                .map { ($0, priorDistances[$0.id] ?? .greatestFiniteMagnitude) }
                .sorted { $0.1 < $1.1 }
        }

        let chosen = Array(sortedWithDistance.prefix(limit))
        let stopsToFetch = chosen.flatMap { $0.group.stops }
        let arrivalsByStop = await ArrivalsService.shared.arrivalsByStop(for: stopsToFetch, limit: 3)

        let slots = chosen.map { item in
            buildSlot(group: item.group,
                      // Don't write infinity to disk — store 0 for "unknown"
                      // so the value is sane if anyone ever surfaces it.
                      distance: item.meters.isFinite ? item.meters : 0,
                      arrivalsByStop: arrivalsByStop)
        }

        let snap = WidgetSnapshot(generatedAt: .now, groups: slots)
        SnapshotStore.write(snap)
        return snap
    }

    /// Build a single GroupSlot from member arrivals.
    public static func buildSlot(group: ResolvedGroup,
                                 distance: Double,
                                 arrivalsByStop: [SavedStop.ID: [Arrival]]) -> WidgetSnapshot.GroupSlot {
        let now = Date()
        let combined = group.stops.flatMap { arrivalsByStop[$0.id] ?? [] }
            .filter { $0.arrivalTime > now.addingTimeInterval(-15) }
            .sorted { $0.arrivalTime < $1.arrivalTime }
        let next = combined.first

        // Direction label: only show when all member stops agree on it.
        let directionLabel: String = {
            let labels = Set(group.stops.map(\.directionLabel))
            return labels.count == 1 ? labels.first ?? "" : ""
        }()

        return .init(
            groupID: group.id,
            displayName: group.displayName,
            lines: group.lines,
            directionLabel: directionLabel,
            distanceMeters: distance,
            nextArrival: next
        )
    }
}
