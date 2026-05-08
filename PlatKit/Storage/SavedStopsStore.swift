import Foundation
import Combine

public final class SavedStopsStore: ObservableObject {
    public static let shared = SavedStopsStore()

    private let key = "savedStops.v1"
    @Published public private(set) var stops: [SavedStop] = []

    private init() { load() }

    public func load() {
        guard let data = AppGroup.defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedStop].self, from: data)
        else { stops = []; return }
        stops = decoded
    }

    public func save(_ stop: SavedStop) {
        if !stops.contains(where: { $0.id == stop.id }) {
            stops.append(stop)
            persist()
        }
    }

    public func remove(_ stop: SavedStop) {
        stops.removeAll { $0.id == stop.id }
        persist()
    }

    public func contains(_ stop: SavedStop) -> Bool {
        stops.contains { $0.id == stop.id }
    }

    /// Resolved groups (singletons + manually combined) in saved-order.
    public var resolvedGroups: [ResolvedGroup] {
        ResolvedGroup.resolve(from: stops)
    }

    /// Merge the given stops into a single group. If any of them already belong
    /// to a group, that group's id is reused (so combining "M15 stop" with
    /// "{M15+M101 group}" extends the existing group).
    public func combine<S: Sequence>(_ toCombine: S) where S.Element == SavedStop {
        let members = Array(toCombine)
        guard members.count >= 2 else { return }
        let existing = members.compactMap(\.groupID).first
        let groupID = existing ?? UUID().uuidString
        for m in members {
            if let i = stops.firstIndex(where: { $0.id == m.id }) {
                stops[i].groupID = groupID
            }
        }
        persist()
    }

    /// Detach a stop from its group. If the group ends up with one member, that
    /// member is also reset to ungrouped (no point in a group of one).
    public func ungroup(_ stop: SavedStop) {
        guard let i = stops.firstIndex(where: { $0.id == stop.id }), let gid = stops[i].groupID else { return }
        stops[i].groupID = nil
        // If the remaining group has only one member left, ungroup it too.
        let remaining = stops.indices.filter { stops[$0].groupID == gid }
        if remaining.count == 1 { stops[remaining[0]].groupID = nil }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stops) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}

public enum SnapshotStore {
    private static let key = "widgetSnapshot.v1"

    public static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    public static func read() -> WidgetSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
