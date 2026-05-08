import Foundation

public struct CatalogStop: Codable, Sendable {
    public let id: String
    public let name: String
    public let lines: [String]
    public let lat: Double
    public let lon: Double

    public func toTransitStop() -> TransitStop {
        TransitStop(id: id, name: name, lines: lines, latitude: lat, longitude: lon)
    }
}

/// Loads the bundled stops.json. Fails over to a tiny built-in seed so the app
/// builds and runs even if the user hasn't run Tools/build_stops_json.sh yet.
public final class StopCatalog {
    public static let shared = StopCatalog()

    public let stops: [TransitStop]
    public let stopsByLine: [String: [TransitStop]]

    private init() {
        let raw = StopCatalog.loadBundled() ?? StopCatalog.seed()
        self.stops = raw.map { $0.toTransitStop() }
        var byLine: [String: [TransitStop]] = [:]
        for s in stops {
            for line in s.lines {
                byLine[line, default: []].append(s)
            }
        }
        // Stable ordering by name so the picker is deterministic.
        for k in byLine.keys {
            byLine[k]?.sort { $0.name < $1.name }
        }
        self.stopsByLine = byLine
    }

    public var allLines: [String] {
        stopsByLine.keys.sorted(by: lineSort)
    }

    public func stops(forLine line: String) -> [TransitStop] {
        stopsByLine[line] ?? []
    }

    private static func loadBundled() -> [CatalogStop]? {
        // Look in the framework bundle and the main bundle (the JSON is
        // bundled into the app target, but the framework runs in both
        // contexts so check both).
        let bundles: [Bundle] = [.main, Bundle(for: StopCatalog.self)]
        for b in bundles {
            if let url = b.url(forResource: "stops", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([CatalogStop].self, from: data) {
                return decoded
            }
        }
        return nil
    }

    private static func seed() -> [CatalogStop] {
        // Minimal sampler so the app boots before you run the build script.
        // Replace by running ./Tools/build_stops_json.sh.
        [
            CatalogStop(id: "635", name: "14 St – Union Sq", lines: ["4","5","6","6X","L","N","Q","R","W"], lat: 40.734673, lon: -73.989951),
            CatalogStop(id: "631", name: "Grand Central – 42 St", lines: ["4","5","6","6X","7","7X"], lat: 40.751776, lon: -73.976848),
            CatalogStop(id: "127", name: "Times Sq – 42 St", lines: ["1","2","3","7","7X","N","Q","R","W"], lat: 40.75529, lon: -73.987495),
            CatalogStop(id: "A41", name: "Jay St – MetroTech", lines: ["A","C","F","R"], lat: 40.692338, lon: -73.987342),
            CatalogStop(id: "L03", name: "Bedford Av", lines: ["L"], lat: 40.717304, lon: -73.956872),
            CatalogStop(id: "G22", name: "Court Sq", lines: ["E","M","G","7","7X"], lat: 40.747846, lon: -73.945740)
        ]
    }
}

/// Sort routes the way New Yorkers read them: numbers first ascending,
/// then the lettered groups roughly by colour family.
fileprivate func lineSort(_ a: String, _ b: String) -> Bool {
    let order: [String] = ["1","2","3","4","5","6","6X","7","7X","A","C","E","B","D","F","M","G","J","Z","L","N","Q","R","W","SI","SIR"]
    let ai = order.firstIndex(of: a) ?? Int.max
    let bi = order.firstIndex(of: b) ?? Int.max
    if ai != bi { return ai < bi }
    return a < b
}
