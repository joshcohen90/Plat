import Foundation

/// Fetches and caches the MTA subway service-alerts feed.
///
/// MTA publishes the GTFS-Realtime alerts feed in both protobuf and JSON
/// serializations. We use the JSON variant so we don't have to drag the
/// Alert / EntitySelector / TranslatedString messages into our trimmed
/// `gtfs-realtime.proto` and regenerate the .pb.swift.
public actor AlertsClient {
    public static let shared = AlertsClient()

    private let session: URLSession
    private struct CacheEntry { let alerts: [ServiceAlert]; let fetchedAt: Date }
    private var cache: CacheEntry?
    private let ttl: TimeInterval = 60

    private static let endpoint = URL(
        string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/camsys%2Fsubway-alerts.json"
    )!

    public init(session: URLSession = .shared) { self.session = session }

    /// All currently-active alerts. Cached briefly so several detail views
    /// hitting this in quick succession share one HTTP fetch.
    public func allActiveAlerts(force: Bool = false) async throws -> [ServiceAlert] {
        if !force, let entry = cache, Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return entry.alerts
        }
        var req = URLRequest(url: Self.endpoint)
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GTFSError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let parsed = (try? Self.parse(data: data)) ?? []
        let active = parsed.filter { $0.isActive() }
        cache = .init(alerts: active, fetchedAt: Date())
        return active
    }

    /// Active alerts that touch any of the given route IDs.
    public func alerts(forLines lines: Set<String>) async throws -> [ServiceAlert] {
        guard !lines.isEmpty else { return [] }
        let all = try await allActiveAlerts()
        return all.filter { !Set($0.routeIDs).isDisjoint(with: lines) }
    }

    /// Map of route_id → alerts active for that line. Convenience for refresh
    /// pipelines that need to attach an alert to each saved-stop slot.
    public func alertsByLine(forLines lines: Set<String>) async -> [String: [ServiceAlert]] {
        guard !lines.isEmpty else { return [:] }
        let active = (try? await allActiveAlerts()) ?? []
        var out: [String: [ServiceAlert]] = [:]
        for alert in active {
            for route in alert.routeIDs where lines.contains(route) {
                out[route, default: []].append(alert)
            }
        }
        return out
    }

    public func clearCache() { cache = nil }

    private static func parse(data: Data) throws -> [ServiceAlert] {
        let envelope = try JSONDecoder().decode(GTFSRTAlertsEnvelope.self, from: data)
        return envelope.entity.compactMap { entity in
            guard let alert = entity.alert else { return nil }
            let routes = (alert.informed_entity ?? [])
                .compactMap { $0.route_id ?? $0.trip?.route_id }
            let unique = Array(Set(routes)).sorted()
            guard !unique.isEmpty else { return nil }

            let effect = ServiceAlert.Effect(rawValue: alert.effect ?? "") ?? .unknownEffect
            let header = alert.header_text?.bestText ?? ""
            let body = alert.description_text?.bestText ?? ""
            let firstPeriod = alert.active_period?.first
            let start = firstPeriod?.start.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            // active_period entries with end == 0 / nil mean "open-ended"
            let end: Date? = {
                guard let raw = firstPeriod?.end, raw > 0 else { return nil }
                return Date(timeIntervalSince1970: TimeInterval(raw))
            }()

            return ServiceAlert(
                id: entity.id,
                routeIDs: unique,
                header: header,
                descriptionText: body,
                effect: effect,
                activeStart: start,
                activeEnd: end
            )
        }
    }
}

// MARK: - JSON shapes (snake_case mirrors the GTFS-RT JSON wire format)

private struct GTFSRTAlertsEnvelope: Decodable {
    let entity: [Entity]

    struct Entity: Decodable {
        let id: String
        let alert: AlertJSON?
    }

    struct AlertJSON: Decodable {
        let active_period: [ActivePeriod]?
        let informed_entity: [InformedEntity]?
        let effect: String?
        let header_text: TranslatedString?
        let description_text: TranslatedString?
    }

    struct ActivePeriod: Decodable { let start: Int64?; let end: Int64? }

    struct InformedEntity: Decodable {
        let route_id: String?
        let stop_id: String?
        let trip: TripDescriptor?

        struct TripDescriptor: Decodable {
            let trip_id: String?
            let route_id: String?
        }
    }

    struct TranslatedString: Decodable {
        let translation: [Translation]?

        var bestText: String {
            let t = translation ?? []
            if let en = t.first(where: { ($0.language ?? "").lowercased().hasPrefix("en") }) {
                return en.text
            }
            return t.first?.text ?? ""
        }
    }

    struct Translation: Decodable {
        let text: String
        let language: String?
    }
}
