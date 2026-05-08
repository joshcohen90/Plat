import Foundation

/// Maps a route_id to the GTFS-Realtime feed URL that publishes its trip updates.
/// MTA splits the subway into feed groups; one HTTP GET per group per refresh.
public enum FeedRouter {
    /// Base endpoint as published at https://api.mta.info/.
    /// No API key required for subway as of late 2022.
    private static let base = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds"

    /// Lines covered per feed group.
    public static let groups: [(slug: String, lines: Set<String>)] = [
        ("nyct%2Fgtfs",       ["1","2","3","4","5","6","6X","7","7X","S","GS","FS","H"]),
        ("nyct%2Fgtfs-ace",   ["A","C","E","H","FS"]),
        ("nyct%2Fgtfs-bdfm",  ["B","D","F","M"]),
        ("nyct%2Fgtfs-g",     ["G"]),
        ("nyct%2Fgtfs-jz",    ["J","Z"]),
        ("nyct%2Fgtfs-l",     ["L"]),
        ("nyct%2Fgtfs-nqrw",  ["N","Q","R","W"]),
        ("nyct%2Fgtfs-si",    ["SI","SIR"]),
    ]

    public static func feedURL(forLine line: String) -> URL? {
        for group in groups where group.lines.contains(line) {
            return URL(string: "\(base)/\(group.slug)")
        }
        return nil
    }

    /// All feeds we need to hit to satisfy a set of saved stops.
    public static func feedURLs(forLines lines: Set<String>) -> [URL] {
        var urls: [URL] = []
        for group in groups where !group.lines.isDisjoint(with: lines) {
            if let u = URL(string: "\(base)/\(group.slug)") { urls.append(u) }
        }
        return urls
    }
}
