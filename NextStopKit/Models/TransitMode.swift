import Foundation

public enum TransitMode: String, Codable, CaseIterable, Sendable {
    case subway, bus

    public var displayName: String {
        switch self { case .subway: "Subway"; case .bus: "Bus" }
    }

    public var systemImage: String {
        switch self { case .subway: "tram.fill"; case .bus: "bus.fill" }
    }
}
