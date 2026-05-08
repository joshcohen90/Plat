import Foundation
import CoreLocation

/// A user-saved transit stop, mode-aware. The realtime layer dispatches by `mode`.
///
/// Wire format note: `directionCode` is mode-specific.
///   - subway: "N" or "S" (becomes the parent stop_id suffix in GTFS-RT)
///   - bus:    "0" or "1" (matches GTFS direction_id; passed as DirectionRef to SIRI)
public struct SavedStop: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(mode.rawValue)|\(stopID)|\(line)|\(directionCode)" }

    public let mode: TransitMode
    public let stopID: String           // subway: parent_station id (e.g. "635"); bus: stop_code (e.g. "400123")
    public let stopName: String
    public let line: String             // route_id ("6", "M15+", etc.)
    public let directionCode: String    // see comment above
    public let directionLabel: String   // human label cached for display
    public let latitude: Double
    public let longitude: Double
    /// Optional manual grouping. Stops sharing a `groupID` are treated as one
    /// physical location for "closest 3" + widget display purposes (e.g. one
    /// bus stop served by multiple lines, or a subway+bus pair at the same corner).
    /// nil → singleton (effective group id is `self.id`).
    public var groupID: String?

    public init(mode: TransitMode, stopID: String, stopName: String, line: String,
                directionCode: String, directionLabel: String,
                latitude: Double, longitude: Double,
                groupID: String? = nil) {
        self.mode = mode
        self.stopID = stopID
        self.stopName = stopName
        self.line = line
        self.directionCode = directionCode
        self.directionLabel = directionLabel
        self.latitude = latitude
        self.longitude = longitude
        self.groupID = groupID
    }

    /// Resolved group key — the explicit groupID, or `self.id` if ungrouped.
    public var effectiveGroupID: String { groupID ?? id }

    public var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    /// Subway-only: GTFS-RT stop_time_update.stop_id format `<parent><N|S>`.
    public var subwayRealtimeStopID: String { "\(stopID)\(directionCode)" }

    /// Bus-only: GTFS direction_id parsed back to Int (0 or 1).
    public var busDirectionID: Int { Int(directionCode) ?? 0 }

    public static func subway(stop: TransitStop, line: String, direction: Direction) -> SavedStop {
        SavedStop(
            mode: .subway,
            stopID: stop.id,
            stopName: stop.name,
            line: line,
            directionCode: direction.rawValue,
            directionLabel: direction.label(forLine: line),
            latitude: stop.latitude,
            longitude: stop.longitude
        )
    }

    public static func bus(stopCode: String, stopName: String, line: String,
                           directionID: Int, headsign: String,
                           latitude: Double, longitude: Double) -> SavedStop {
        SavedStop(
            mode: .bus,
            stopID: stopCode,
            stopName: stopName,
            line: line,
            directionCode: String(directionID),
            directionLabel: headsign,
            latitude: latitude,
            longitude: longitude
        )
    }
}
