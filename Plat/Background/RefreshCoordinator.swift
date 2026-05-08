import Foundation
import CoreLocation
import WidgetKit
import PlatKit

/// Owns the "compute closest 3 + fetch arrivals + write snapshot" pipeline.
/// Called from: foreground app launch, location change, pull-to-refresh, BGAppRefreshTask.
public actor RefreshCoordinator {
    public static let shared = RefreshCoordinator()

    public enum Reason: String {
        case appLaunch, locationChanged, pullToRefresh, savedStopsChanged, backgroundTask
    }

    private var lastRunAt: Date?
    private let minInterval: TimeInterval = 20

    public func refresh(reason: Reason) async {
        // Debounce only automatic background-style triggers. User actions and
        // location callbacks (which CoreLocation has already rate-limited by
        // a ~500m threshold) always go through. Otherwise a launch-time
        // refresh runs with no location fix yet, and the first location
        // callback that follows gets swallowed before it can re-rank by
        // distance — which is what the user reported as "closest is in the
        // middle of the list."
        switch reason {
        case .appLaunch, .backgroundTask:
            if let last = lastRunAt, Date().timeIntervalSince(last) < minInterval { return }
        case .locationChanged, .pullToRefresh, .savedStopsChanged:
            break
        }
        lastRunAt = Date()

        let saved = SavedStopsStore.shared.stops
        guard !saved.isEmpty else {
            SnapshotStore.write(.init(generatedAt: .now, groups: []))
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let groups = ResolvedGroup.resolve(from: saved)
        let coord = await currentCoordinate()

        // Sort groups by distance to user (centroid), or preserve saved order if no fix.
        let sortedGroups: [(group: ResolvedGroup, meters: Double)] = {
            guard let coord else {
                return groups.map { ($0, 0.0) }
            }
            let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return groups
                .map { ($0, here.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude))) }
                .sorted { $0.1 < $1.1 }
        }()

        let chosen = Array(sortedGroups.prefix(3))
        let stopsToFetch = chosen.flatMap { $0.group.stops }

        async let arrivalsTask = ArrivalsService.shared.arrivalsByStop(for: stopsToFetch, limit: 3)
        let subwayLines = Set(stopsToFetch.compactMap { $0.mode == .subway ? $0.line : nil })
        async let alertsTask = AlertsClient.shared.alertsByLine(forLines: subwayLines)

        let arrivalsByStop = await arrivalsTask
        let alertsByLine = await alertsTask

        let slots = chosen.map { item in
            SnapshotRefresher.buildSlot(
                group: item.group,
                distance: item.meters,
                arrivalsByStop: arrivalsByStop,
                alertsByLine: alertsByLine
            )
        }
        let snapshot = WidgetSnapshot(generatedAt: .now, groups: slots)
        SnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    private func currentCoordinate() async -> CLLocationCoordinate2D? {
        LocationManager.shared.lastLocation?.coordinate
    }
}
