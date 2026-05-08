import Foundation
import CoreLocation

/// Resolved view of one logical location: either a single SavedStop (singleton)
/// or several SavedStops sharing a manual groupID. Distance is computed against
/// the centroid of member stops.
public struct ResolvedGroup: Identifiable, Hashable, Sendable {
    public let id: String                 // effective group id
    public let displayName: String        // representative name (longest member name; ties broken by first)
    public let coordinate: Coord
    public let stops: [SavedStop]

    public struct Coord: Hashable, Sendable {
        public let latitude: Double
        public let longitude: Double
        public var clCoordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    }

    public var isGrouped: Bool { stops.count > 1 }
    public var lines: [String] {
        var seen: Set<String> = []
        return stops.compactMap { s in seen.insert(s.line).inserted ? s.line : nil }
    }

    public init(id: String, displayName: String, coordinate: Coord, stops: [SavedStop]) {
        self.id = id; self.displayName = displayName
        self.coordinate = coordinate; self.stops = stops
    }

    /// Build groups from a flat list of saved stops. Stops sharing `effectiveGroupID` collapse together.
    public static func resolve(from stops: [SavedStop]) -> [ResolvedGroup] {
        var byID: [String: [SavedStop]] = [:]
        var order: [String] = []
        for s in stops {
            let k = s.effectiveGroupID
            if byID[k] == nil { order.append(k) }
            byID[k, default: []].append(s)
        }
        return order.compactMap { id in
            guard let members = byID[id], !members.isEmpty else { return nil }
            let lat = members.map(\.latitude).reduce(0,+) / Double(members.count)
            let lon = members.map(\.longitude).reduce(0,+) / Double(members.count)
            let name = members.max(by: { $0.stopName.count < $1.stopName.count })?.stopName ?? ""
            return ResolvedGroup(
                id: id,
                displayName: name,
                coordinate: .init(latitude: lat, longitude: lon),
                stops: members
            )
        }
    }
}
