import SwiftUI
import PlatKit

/// Detail view for a manually combined group: one chronological feed merging
/// arrivals across every member stop, with each row attributed to its source
/// stop / line / direction.
struct CombinedStopDetailView: View {
    let group: ResolvedGroup
    @EnvironmentObject private var saved: SavedStopsStore

    @State private var arrivalsByStop: [SavedStop.ID: [Arrival]] = [:]
    @State private var alerts: [ServiceAlert] = []
    @State private var loading = false
    @State private var error: String?

    private struct FeedRow: Hashable {
        let stop: SavedStop
        let arrival: Arrival
    }

    private var feed: [FeedRow] {
        let now = Date()
        return group.stops.flatMap { stop in
            (arrivalsByStop[stop.id] ?? []).map { FeedRow(stop: stop, arrival: $0) }
        }
        .filter { $0.arrival.arrivalTime > now.addingTimeInterval(-15) }
        .sorted { $0.arrival.arrivalTime < $1.arrival.arrivalTime }
    }

    /// Use the live store copy of `group` if it still exists — that way swipe
    /// actions (ungroup / remove a member) update the list without us having
    /// to dismiss the view.
    private var liveGroup: ResolvedGroup {
        saved.resolvedGroups.first(where: { $0.id == group.id }) ?? group
    }

    var body: some View {
        List {
            headerSection
            if !alerts.isEmpty {
                Section("Service alerts") {
                    ForEach(alerts) { ServiceAlertRow(alert: $0) }
                }
            }
            arrivalsSection
            membersSection
        }
        .navigationTitle(liveGroup.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                CombinedRouteCluster(stops: liveGroup.stops)
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveGroup.displayName).font(.headline).lineLimit(2)
                    Label("Combined · \(liveGroup.stops.count) stops",
                          systemImage: "rectangle.stack.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let topEffect = alerts.map(\.effect).max(by: { $0.severity < $1.severity }) {
                        AlertPill(effect: topEffect)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var arrivalsSection: some View {
        Section("Next arrivals") {
            if loading && feed.isEmpty {
                ProgressView()
            } else if let error {
                Text(error).foregroundStyle(.red)
            } else if feed.isEmpty {
                Text("No arrivals reported.").foregroundStyle(.secondary)
            } else {
                ForEach(feed.prefix(12), id: \.self) { row in
                    ArrivalListRow(arrival: row.arrival, stopAttribution: row.stop)
                }
            }
        }
    }

    private var membersSection: some View {
        Section("Stops in this group") {
            ForEach(liveGroup.stops) { stop in
                NavigationLink(value: stop) {
                    SavedStopRow(stop: stop, showsChevron: false)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        saved.ungroup(stop)
                        Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
                    } label: { Label("Ungroup", systemImage: "rectangle.split.2x1") }
                    .tint(.orange)
                    Button(role: .destructive) {
                        saved.remove(stop)
                        Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }

    private func reload() async {
        loading = true; defer { loading = false }
        let stops = liveGroup.stops
        let subwayLines = Set(stops.compactMap { $0.mode == .subway ? $0.line : nil })
        async let arrivalsTask = ArrivalsService.shared.arrivalsByStop(for: stops, limit: 8)
        async let alertsTask = AlertsClient.shared.alerts(forLines: subwayLines)
        arrivalsByStop = await arrivalsTask
        alerts = (try? await alertsTask) ?? []
        error = nil
    }
}

/// Stacked badges for up to 3 unique lines/modes in a combined group. Used in
/// both the Saved Stops row and the combined feed header.
struct CombinedRouteCluster: View {
    let stops: [SavedStop]

    private var unique: [SavedStop] {
        var seen: Set<String> = []
        return stops.filter { s in
            seen.insert("\(s.mode.rawValue)|\(s.line)").inserted
        }
    }

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(unique.prefix(3).enumerated()), id: \.offset) { idx, stop in
                RouteBadge(stop: stop)
                    .zIndex(Double(3 - idx))
            }
        }
    }
}
