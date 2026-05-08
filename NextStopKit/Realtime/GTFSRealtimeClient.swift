import Foundation
import SwiftProtobuf

public actor GTFSRealtimeClient {
    public static let shared = GTFSRealtimeClient()

    private let session: URLSession
    private struct CacheEntry { let arrivals: [Arrival]; let fetchedAt: Date }
    private var cache: [URL: CacheEntry] = [:]
    private let ttl: TimeInterval = 45  // MTA feeds update every ~30s

    public init(session: URLSession = .shared) { self.session = session }

    /// Fetches and parses one feed. Returns ALL arrivals across the feed; the
    /// caller filters by stop_id + direction. Cached briefly so a refresh of
    /// many stops on one feed only hits the network once.
    public func arrivals(from url: URL, force: Bool = false) async throws -> [Arrival] {
        if !force, let entry = cache[url], Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return entry.arrivals
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GTFSError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
        let arrivals = Self.extractArrivals(from: feed)
        cache[url] = .init(arrivals: arrivals, fetchedAt: Date())
        return arrivals
    }

    public func clearCache() { cache.removeAll() }

    private static func extractArrivals(from feed: TransitRealtime_FeedMessage) -> [Arrival] {
        var out: [Arrival] = []
        out.reserveCapacity(feed.entity.count * 4)
        for entity in feed.entity where entity.hasTripUpdate {
            let trip = entity.tripUpdate
            let routeID = trip.trip.routeID
            for stu in trip.stopTimeUpdate {
                let raw = stu.stopID
                guard let last = raw.last, last == "N" || last == "S" else { continue }
                let unix: Int64
                if stu.hasArrival, stu.arrival.time > 0 {
                    unix = stu.arrival.time
                } else if stu.hasDeparture, stu.departure.time > 0 {
                    unix = stu.departure.time
                } else { continue }

                out.append(Arrival(
                    mode: .subway,
                    line: routeID,
                    stopID: raw,
                    directionCode: String(last),
                    arrivalTime: Date(timeIntervalSince1970: TimeInterval(unix)),
                    tripID: trip.trip.tripID
                ))
            }
        }
        return out
    }
}

public enum GTFSError: Error, LocalizedError {
    case badStatus(Int)
    case decode

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code): "Feed returned HTTP \(code)"
        case .decode: "Could not decode feed"
        }
    }
}
