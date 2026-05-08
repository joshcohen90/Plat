import Foundation

/// Client for MTA bustime.mta.info SIRI StopMonitoring (JSON).
/// Docs: https://bustime.mta.info/wiki/Developers/SIRIIntro
///
/// One HTTP call per saved bus stop per refresh — small fan-out (≤3 in our use case).
public actor BusTimeClient {
    public static let shared = BusTimeClient()

    private let session: URLSession
    private struct CacheKey: Hashable { let code: String; let line: String; let dir: Int }
    private struct CacheEntry { let arrivals: [Arrival]; let fetchedAt: Date }
    private var cache: [CacheKey: CacheEntry] = [:]
    private let ttl: TimeInterval = 30   // SIRI publishes new vehicle positions ~every 30s

    public init(session: URLSession = .shared) { self.session = session }

    public func arrivals(forStopCode stopCode: String,
                         line: String,
                         directionID: Int,
                         limit: Int = 8,
                         force: Bool = false) async throws -> [Arrival] {
        let key = CacheKey(code: stopCode, line: line, dir: directionID)
        if !force, let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return Array(entry.arrivals.prefix(limit))
        }

        var comps = URLComponents(string: "https://bustime.mta.info/api/siri/stop-monitoring.json")!
        comps.queryItems = [
            URLQueryItem(name: "key", value: Secrets.busTimeAPIKey),
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "MonitoringRef", value: stopCode),
            URLQueryItem(name: "LineRef", value: "MTA NYCT_\(line)"),
            URLQueryItem(name: "DirectionRef", value: String(directionID)),
            URLQueryItem(name: "MaximumStopVisits", value: String(max(limit, 4)))
        ]
        guard let url = comps.url else { throw GTFSError.badStatus(-1) }

        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GTFSError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // SIRI dates have fractional seconds + timezone offsets; ISO8601 handles both.
        let envelope = try decoder.decode(SIRIEnvelope.self, from: data)
        let arrivals = Self.extractArrivals(envelope: envelope, line: line, directionID: directionID)
            .sorted { $0.arrivalTime < $1.arrivalTime }

        cache[key] = .init(arrivals: arrivals, fetchedAt: Date())
        return Array(arrivals.prefix(limit))
    }

    public func clearCache() { cache.removeAll() }

    private static func extractArrivals(envelope: SIRIEnvelope, line: String, directionID: Int) -> [Arrival] {
        let visits = envelope.Siri.ServiceDelivery.StopMonitoringDelivery.flatMap { $0.MonitoredStopVisit ?? [] }
        var out: [Arrival] = []
        out.reserveCapacity(visits.count)
        let now = Date()
        for v in visits {
            let journey = v.MonitoredVehicleJourney
            guard let call = journey.MonitoredCall else { continue }
            // Prefer Expected, fall back to Aimed (scheduled).
            let when = call.ExpectedArrivalTime ?? call.ExpectedDepartureTime
                    ?? call.AimedArrivalTime ?? call.AimedDepartureTime
            guard let arrivalTime = when, arrivalTime > now.addingTimeInterval(-30) else { continue }

            out.append(Arrival(
                mode: .bus,
                line: line,
                stopID: call.StopPointRef ?? "",
                directionCode: String(directionID),
                arrivalTime: arrivalTime,
                tripID: journey.JourneyPatternRef,
                vehicleRef: journey.VehicleRef
            ))
        }
        return out
    }
}

// MARK: - SIRI 2.0 minimal decode shapes
// Only the fields we actually consume.

private struct SIRIEnvelope: Decodable { let Siri: SIRIRoot }
private struct SIRIRoot: Decodable { let ServiceDelivery: ServiceDelivery }
private struct ServiceDelivery: Decodable {
    let StopMonitoringDelivery: [StopMonitoringDelivery]
}
private struct StopMonitoringDelivery: Decodable {
    let MonitoredStopVisit: [MonitoredStopVisit]?
}
private struct MonitoredStopVisit: Decodable {
    let MonitoredVehicleJourney: MonitoredVehicleJourney
}
private struct MonitoredVehicleJourney: Decodable {
    let LineRef: String?
    let DirectionRef: String?
    let JourneyPatternRef: String?
    let VehicleRef: String?
    let MonitoredCall: MonitoredCall?
}
private struct MonitoredCall: Decodable {
    let StopPointRef: String?
    let ExpectedArrivalTime: Date?
    let ExpectedDepartureTime: Date?
    let AimedArrivalTime: Date?
    let AimedDepartureTime: Date?
}
