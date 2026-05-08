import WidgetKit
import SwiftUI
import PlatKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        .init(date: .now, snapshot: Self.sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(.init(date: .now, snapshot: SnapshotStore.read() ?? Self.sample()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snap = SnapshotStore.read()
        let entry = SnapshotEntry(date: .now, snapshot: snap)
        completion(.init(entries: [entry], policy: .after(nextReloadDate(for: snap))))
    }

    private func nextReloadDate(for snap: WidgetSnapshot?) -> Date {
        let now = Date()
        guard let snap, let soonest = snap.groups.compactMap(\.nextArrival?.arrivalTime).min() else {
            return now.addingTimeInterval(5 * 60)
        }
        let target = soonest.addingTimeInterval(-30)
        return min(max(target, now.addingTimeInterval(60)), now.addingTimeInterval(5 * 60))
    }

    static func sample() -> WidgetSnapshot {
        let arr1 = Arrival(mode: .subway, line: "6", stopID: "635S", directionCode: "S",
                           arrivalTime: .now.addingTimeInterval(120))
        let arr2 = Arrival(mode: .bus, line: "M15+", stopID: "400069", directionCode: "0",
                           arrivalTime: .now.addingTimeInterval(360))
        let arr3 = Arrival(mode: .subway, line: "L", stopID: "L03N", directionCode: "N",
                           arrivalTime: .now.addingTimeInterval(540))
        return WidgetSnapshot(generatedAt: .now, groups: [
            .init(groupID: "g1", displayName: "14 St – Union Sq",
                  lines: ["6","L"], directionLabel: "Downtown",
                  distanceMeters: 220, nextArrival: arr1),
            .init(groupID: "g2", displayName: "1 Av / 14 St",
                  lines: ["M15+","M14A+"], directionLabel: "South Ferry",
                  distanceMeters: 410, nextArrival: arr2),
            .init(groupID: "g3", displayName: "Bedford Av",
                  lines: ["L"], directionLabel: "8 Av",
                  distanceMeters: 980, nextArrival: arr3)
        ])
    }
}
