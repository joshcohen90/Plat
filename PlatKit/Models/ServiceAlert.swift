import Foundation

/// One MTA service alert affecting one or more subway routes.
///
/// Sourced from the GTFS-Realtime alerts feed
/// (`camsys%2Fsubway-alerts.json`). MTA does not populate per-trip
/// `StopTimeEvent.delay`, so route-level alerts (e.g. SIGNIFICANT_DELAYS,
/// REDUCED_SERVICE) are the canonical signal that a line is degraded.
public struct ServiceAlert: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let routeIDs: [String]
    public let header: String
    public let descriptionText: String
    public let effect: Effect
    public let activeStart: Date?
    public let activeEnd: Date?

    public enum Effect: String, Codable, Sendable {
        case noService          = "NO_SERVICE"
        case reducedService     = "REDUCED_SERVICE"
        case significantDelays  = "SIGNIFICANT_DELAYS"
        case detour             = "DETOUR"
        case modifiedService    = "MODIFIED_SERVICE"
        case additionalService  = "ADDITIONAL_SERVICE"
        case stopMoved          = "STOP_MOVED"
        case accessibilityIssue = "ACCESSIBILITY_ISSUE"
        case noEffect           = "NO_EFFECT"
        case otherEffect        = "OTHER_EFFECT"
        case unknownEffect      = "UNKNOWN_EFFECT"

        /// Higher = more disruptive. Used to pick a single representative alert
        /// when several apply to the same line.
        public var severity: Int {
            switch self {
            case .noService:          return 5
            case .significantDelays:  return 4
            case .reducedService:     return 3
            case .detour:             return 2
            case .modifiedService:    return 1
            default:                  return 0
            }
        }

        public var isMajor: Bool { severity >= 1 }

        /// Compact label for badges.
        public var shortLabel: String {
            switch self {
            case .noService:          return "Suspended"
            case .significantDelays:  return "Delays"
            case .reducedService:     return "Reduced"
            case .detour:             return "Reroute"
            case .modifiedService:    return "Modified"
            case .additionalService:  return "Extra"
            case .accessibilityIssue: return "Access"
            case .stopMoved:          return "Moved"
            default:                  return "Alert"
            }
        }
    }

    public init(id: String, routeIDs: [String], header: String, descriptionText: String,
                effect: Effect, activeStart: Date?, activeEnd: Date?) {
        self.id = id
        self.routeIDs = routeIDs
        self.header = header
        self.descriptionText = descriptionText
        self.effect = effect
        self.activeStart = activeStart
        self.activeEnd = activeEnd
    }

    public func isActive(at date: Date = .now) -> Bool {
        if let activeStart, date < activeStart { return false }
        if let activeEnd,   date > activeEnd   { return false }
        return true
    }
}

public extension Sequence where Element == ServiceAlert {
    /// Most-severe alert in the sequence, nil if none. Ties broken arbitrarily.
    var mostSevere: ServiceAlert? {
        self.max { $0.effect.severity < $1.effect.severity }
    }
}
