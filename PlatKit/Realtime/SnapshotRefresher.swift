import Foundation
import CoreLocation

/// Refresher used by the widget intent. Doesn't have access to live location,
/// so it reuses distances from the prior snapshot when available.
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
        let priorDistances = SnapshotStore.read()
            .map { Dictionary(uniqueKeysWithValues: $0.groups.map { ($0.groupID, $0.distanceMeters) }) }
            ?? [:]

        // Order by prior distance if known, else preserve saved order.
        let sortedGroups = groups.sorted {
            (priorDistances[$0.id] ?? .greatestFiniteMagnitude) < (priorDistances[$1.id] ?? .greatestFiniteMagnitude)
        }
        let chosen = Array(sortedGroups.prefix(limit))

        let stopsToFetch = chosen.flatMap(\.stops)
        let arrivalsByStop = await ArrivalsService.shared.arrivalsByStop(for: stopsToFetch, limit: 3)

        let slots = chosen.map { group in
            buildSlot(group: group,
                      distance: priorDistances[group.id] ?? 0,
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
