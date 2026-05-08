import Foundation

/// Bus stop record. Unlike subway, bus stops are PER-DIRECTION (no parent station).
/// `code` matches the SIRI MonitoringRef.
public struct BusStopRecord: Codable, Sendable, Hashable, Identifiable {
    public var id: String { "\(line)|\(code)|\(directionID)" }
    public let code: String          // GTFS stop_id, e.g. "400123"
    public let name: String          // stop name
    public let lat: Double
    public let lon: Double
    public let line: String          // route_id, e.g. "M15+"
    public let directionID: Int      // 0 or 1
    public let headsign: String      // human-readable destination, e.g. "South Ferry via 2 Av"
}

public final class BusStopCatalog {
    public static let shared = BusStopCatalog()

    public let stops: [BusStopRecord]

    /// route_id → set of (directionID, headsign)
    public let directionsByLine: [String: [(directionID: Int, headsign: String)]]

    /// (route_id, directionID) → stops in stop_sequence order (alphabetical fallback)
    public let stopsByLineDirection: [String: [BusStopRecord]]

    public var allLines: [String] {
        directionsByLine.keys.sorted(by: BusStopCatalog.routeSort)
    }

    private init() {
        let raw = BusStopCatalog.loadBundled() ?? BusStopCatalog.seed()
        self.stops = raw

        var dirs: [String: [(Int, String)]] = [:]
        var byLD: [String: [BusStopRecord]] = [:]
        for s in raw {
            let key = "\(s.line)|\(s.directionID)"
            byLD[key, default: []].append(s)
            let entry = (s.directionID, s.headsign)
            if !(dirs[s.line] ?? []).contains(where: { $0.0 == s.directionID }) {
                dirs[s.line, default: []].append(entry)
            }
        }
        for k in byLD.keys { byLD[k]?.sort { $0.name < $1.name } }
        self.directionsByLine = dirs
        self.stopsByLineDirection = byLD
    }

    public func directions(forLine line: String) -> [(directionID: Int, headsign: String)] {
        directionsByLine[line] ?? []
    }

    public func stops(forLine line: String, direction: Int) -> [BusStopRecord] {
        stopsByLineDirection["\(line)|\(direction)"] ?? []
    }

    /// All catalog rows for the given stop code (one row per route+direction serving it).
    public func records(forStopCode code: String) -> [BusStopRecord] {
        stops.filter { $0.code == code }
    }

    /// Substring match against stop code. Used for the "by stop #" picker.
    public func records(matchingCodePrefix prefix: String, limit: Int = 200) -> [BusStopRecord] {
        guard !prefix.isEmpty else { return [] }
        var out: [BusStopRecord] = []
        for s in stops where s.code.hasPrefix(prefix) {
            out.append(s)
            if out.count >= limit { break }
        }
        return out
    }

    private static func loadBundled() -> [BusStopRecord]? {
        let bundles: [Bundle] = [.main, Bundle(for: BusStopCatalog.self)]
        for b in bundles {
            if let url = b.url(forResource: "bus_stops", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([BusStopRecord].self, from: data) {
                return decoded
            }
        }
        return nil
    }

    private static func seed() -> [BusStopRecord] {
        // Tiny seed so the bus picker isn't empty before build_bus_stops_json.sh runs.
        [
            .init(code: "400069", name: "1 Av / E 14 St", lat: 40.731430, lon: -73.981802,
                  line: "M15+", directionID: 0, headsign: "South Ferry via 2 Av"),
            .init(code: "404947", name: "2 Av / E 14 St", lat: 40.731815, lon: -73.984068,
                  line: "M15+", directionID: 1, headsign: "E 125 St via 1 Av"),
        ]
    }

    /// Bus route sort: borough prefix then number, with `+` (Select Bus Service) after the base.
    fileprivate static func routeSort(_ a: String, _ b: String) -> Bool {
        func decompose(_ s: String) -> (prefix: String, num: Int, plus: Bool) {
            let plus = s.hasSuffix("+")
            let core = plus ? String(s.dropLast()) : s
            let prefix = String(core.prefix { $0.isLetter })
            let num = Int(core.drop { $0.isLetter }) ?? Int.max
            return (prefix, num, plus)
        }
        let A = decompose(a), B = decompose(b)
        if A.prefix != B.prefix { return A.prefix < B.prefix }
        if A.num != B.num { return A.num < B.num }
        return !A.plus && B.plus
    }
}
