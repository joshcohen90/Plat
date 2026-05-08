import Foundation

public struct Arrival: Codable, Hashable, Sendable {
    public let mode: TransitMode
    public let line: String
    public let stopID: String           // subway realtime id (parent+N/S) or bus stop code
    public let directionCode: String    // mode-specific (see SavedStop)
    public let arrivalTime: Date
    public let tripID: String?
    public let vehicleRef: String?      // bus: VehicleRef from SIRI; subway: nil

    public init(mode: TransitMode, line: String, stopID: String, directionCode: String,
                arrivalTime: Date, tripID: String? = nil, vehicleRef: String? = nil) {
        self.mode = mode; self.line = line; self.stopID = stopID
        self.directionCode = directionCode; self.arrivalTime = arrivalTime
        self.tripID = tripID; self.vehicleRef = vehicleRef
    }

    public func minutesAway(now: Date = .now) -> Int {
        max(0, Int((arrivalTime.timeIntervalSince(now) / 60).rounded()))
    }
}

/// Snapshot the app writes to App Group storage for the widget to consume.
/// One entry per logical location ("group"), max 3, ordered closest first.
public struct WidgetSnapshot: Codable, Sendable {
    public struct GroupSlot: Codable, Sendable, Identifiable, Hashable {
        public var id: String { groupID }
        public let groupID: String
        public let displayName: String
        public let lines: [String]            // unique lines across the group's members (badge order)
        public let directionLabel: String     // shown when all members agree on a direction; "" otherwise
        public let distanceMeters: Double
        /// Soonest arrival across all member stops in this group, or nil if none.
        public let nextArrival: Arrival?

        public init(groupID: String, displayName: String, lines: [String], directionLabel: String,
                    distanceMeters: Double, nextArrival: Arrival?) {
            self.groupID = groupID; self.displayName = displayName
            self.lines = lines; self.directionLabel = directionLabel
            self.distanceMeters = distanceMeters; self.nextArrival = nextArrival
        }
    }

    public let generatedAt: Date
    public let groups: [GroupSlot]

    public init(generatedAt: Date, groups: [GroupSlot]) {
        self.generatedAt = generatedAt
        self.groups = groups
    }
}
