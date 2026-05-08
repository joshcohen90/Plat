import SwiftUI
import PlatKit

struct StopDetailView: View {
    let stop: SavedStop
    @State private var arrivals: [Arrival] = []
    @State private var alerts: [ServiceAlert] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    RouteBadge(stop: stop)
                    VStack(alignment: .leading) {
                        Text(stop.stopName).font(.headline)
                        Text(stop.directionLabel)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            if !alerts.isEmpty {
                Section("Service alerts") {
                    ForEach(alerts) { ServiceAlertRow(alert: $0) }
                }
            }

            Section("Next arrivals") {
                if loading && arrivals.isEmpty {
                    ProgressView()
                } else if let error {
                    Text(error).foregroundStyle(.red)
                } else if arrivals.isEmpty {
                    Text("No arrivals reported.").foregroundStyle(.secondary)
                } else {
                    ForEach(arrivals.prefix(8), id: \.self) { arr in
                        ArrivalListRow(arrival: arr)
                    }
                }
            }
        }
        .navigationTitle("\(stop.line) – \(stop.stopName)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        loading = true; defer { loading = false }
        async let arrivalsTask = ArrivalsService.shared.arrivals(for: stop)
        async let alertsTask = fetchAlerts()
        do {
            arrivals = try await arrivalsTask
            alerts = await alertsTask
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Subway-only: pull alerts for this line. Bus has no equivalent
    /// route-level alerts feed in our pipeline.
    private func fetchAlerts() async -> [ServiceAlert] {
        guard stop.mode == .subway else { return [] }
        return (try? await AlertsClient.shared.alerts(forLines: [stop.line])) ?? []
    }
}

/// Shared arrival row used by per-stop and combined feeds.
struct ArrivalListRow: View {
    let arrival: Arrival
    var stopAttribution: SavedStop? = nil

    var body: some View {
        HStack(spacing: 12) {
            switch arrival.mode {
            case .subway: LineBullet(line: arrival.line)
            case .bus:    BusBadge(line: arrival.line)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(arrival.minutesAway()) min")
                        .font(.body.monospacedDigit().weight(.semibold))
                    Text(arrival.arrivalTime, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let attribution = stopAttribution {
                    Text(attributionText(for: attribution))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func attributionText(for stop: SavedStop) -> String {
        let dir = stop.directionLabel
        return dir.isEmpty ? stop.stopName : "\(dir) · \(stop.stopName)"
    }
}

/// One row in the "Service alerts" section: effect pill + headline +
/// description (truncated; tap to expand).
struct ServiceAlertRow: View {
    let alert: ServiceAlert
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AlertPill(effect: alert.effect)
                Text(alert.routeIDs.joined(separator: ", "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if !alert.header.isEmpty {
                Text(alert.header)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(expanded ? nil : 3)
            }
            if !alert.descriptionText.isEmpty && expanded {
                Text(alert.descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !alert.descriptionText.isEmpty {
                Button(expanded ? "Show less" : "Show more") {
                    expanded.toggle()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 2)
    }
}
