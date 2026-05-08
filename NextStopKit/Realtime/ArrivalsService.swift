import Foundation

public actor ArrivalsService {
    public static let shared = ArrivalsService()

    private let subway: GTFSRealtimeClient
    private let bus: BusTimeClient

    public init(subway: GTFSRealtimeClient = .shared, bus: BusTimeClient = .shared) {
        self.subway = subway; self.bus = bus
    }

    /// Arrivals for a single saved stop. Dispatches by mode.
    public func arrivals(for saved: SavedStop, limit: Int = 8) async throws -> [Arrival] {
        switch saved.mode {
        case .subway:
            guard let url = FeedRouter.feedURL(forLine: saved.line) else { return [] }
            let all = try await subway.arrivals(from: url)
            return Self.filterSubway(all, for: saved, limit: limit)
        case .bus:
            return try await bus.arrivals(forStopCode: saved.stopID, line: saved.line,
                                          directionID: saved.busDirectionID, limit: limit)
        }
    }

    /// Bulk: fetch each unique source once, then bucket arrivals by saved stop.
    public func arrivalsByStop(for stops: [SavedStop], limit: Int = 4) async -> [SavedStop.ID: [Arrival]] {
        var result: [SavedStop.ID: [Arrival]] = [:]

        let subwayStops = stops.filter { $0.mode == .subway }
        let busStops = stops.filter { $0.mode == .bus }

        async let subwayResults = bulkSubway(subwayStops, limit: limit)
        async let busResults = bulkBus(busStops, limit: limit)

        for (k, v) in await subwayResults { result[k] = v }
        for (k, v) in await busResults { result[k] = v }
        return result
    }

    private func bulkSubway(_ stops: [SavedStop], limit: Int) async -> [SavedStop.ID: [Arrival]] {
        guard !stops.isEmpty else { return [:] }
        let lines = Set(stops.map(\.line))
        let urls = FeedRouter.feedURLs(forLines: lines)

        var feedArrivals: [Arrival] = []
        await withTaskGroup(of: [Arrival].self) { group in
            for url in urls {
                group.addTask { [subway] in (try? await subway.arrivals(from: url)) ?? [] }
            }
            for await batch in group { feedArrivals.append(contentsOf: batch) }
        }

        var out: [SavedStop.ID: [Arrival]] = [:]
        for s in stops { out[s.id] = Self.filterSubway(feedArrivals, for: s, limit: limit) }
        return out
    }

    private func bulkBus(_ stops: [SavedStop], limit: Int) async -> [SavedStop.ID: [Arrival]] {
        guard !stops.isEmpty else { return [:] }
        var out: [SavedStop.ID: [Arrival]] = [:]
        await withTaskGroup(of: (SavedStop.ID, [Arrival]).self) { group in
            for s in stops {
                group.addTask { [bus] in
                    let arr = (try? await bus.arrivals(
                        forStopCode: s.stopID, line: s.line,
                        directionID: s.busDirectionID, limit: limit
                    )) ?? []
                    return (s.id, arr)
                }
            }
            for await (id, arr) in group { out[id] = arr }
        }
        return out
    }

    private static func filterSubway(_ all: [Arrival], for saved: SavedStop, limit: Int) -> [Arrival] {
        let target = saved.subwayRealtimeStopID
        let now = Date()
        return all
            .filter { $0.stopID == target && $0.line == saved.line && $0.arrivalTime > now.addingTimeInterval(-15) }
            .sorted { $0.arrivalTime < $1.arrivalTime }
            .prefix(limit)
            .map { $0 }
    }
}
