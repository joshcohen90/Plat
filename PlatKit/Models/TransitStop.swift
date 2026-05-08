import Foundation
import CoreLocation

public struct TransitStop: Codable, Hashable, Identifiable, Sendable {
    public let id: String           // GTFS stop_id of the parent station (e.g. "635" for Union Sq)
    public let name: String
    public let lines: [String]      // ["4","5","6","6X"]
    public let latitude: Double
    public let longitude: Double

    public init(id: String, name: String, lines: [String], latitude: Double, longitude: Double) {
        self.id = id; self.name = name; self.lines = lines
        self.latitude = latitude; self.longitude = longitude
    }

    public var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}

/// One direction of travel at a station. GTFS subway encodes direction with the
/// stop_id suffix: `<parent>N` (north / uptown / queens-bound) or `<parent>S` (south / downtown / brooklyn-bound).
public enum Direction: String, Codable, Hashable, CaseIterable, Sendable {
    case north = "N"
    case south = "S"

    public var stopIDSuffix: String { rawValue }

    /// Human-readable label, scoped per-line because "north" means different
    /// things on different routes. Falls back to a generic label when unknown.
    public func label(forLine line: String) -> String {
        switch (line, self) {
        case ("1", .north), ("2", .north), ("3", .north): "Uptown & The Bronx"
        case ("1", .south), ("2", .south), ("3", .south): "Downtown & Brooklyn"
        case ("4", .north), ("5", .north), ("6", .north), ("6X", .north): "Uptown & The Bronx"
        case ("4", .south), ("5", .south), ("6", .south), ("6X", .south): "Downtown & Brooklyn"
        case ("7", .north), ("7X", .north): "Flushing"
        case ("7", .south), ("7X", .south): "Manhattan"
        case ("A", .north), ("C", .north), ("E", .north): "Uptown / Queens"
        case ("A", .south), ("C", .south), ("E", .south): "Downtown / Brooklyn"
        case ("B", .north), ("D", .north), ("F", .north), ("M", .north): "Uptown / Bronx / Queens"
        case ("B", .south), ("D", .south), ("F", .south), ("M", .south): "Downtown / Brooklyn"
        case ("G", .north): "Court Sq"
        case ("G", .south): "Church Av"
        case ("J", .north), ("Z", .north): "Jamaica Center"
        case ("J", .south), ("Z", .south): "Manhattan"
        case ("L", .north): "8 Av"
        case ("L", .south): "Canarsie"
        case ("N", .north), ("Q", .north), ("R", .north), ("W", .north): "Uptown / Queens"
        case ("N", .south), ("Q", .south), ("R", .south), ("W", .south): "Downtown / Brooklyn / Coney Is"
        case (_, .north): "Northbound"
        case (_, .south): "Southbound"
        }
    }
}
