import SwiftUI
import PlatKit

/// Detail view for a manually combined group: one chronological feed merging
/// arrivals across every member stop, with each row attributed to its source
/// stop / line / direction.
struct CombinedStopDetailView: View {
    let group: ResolvedGroup
    @EnvironmentObject private var saved: SavedStopsStore

    @State private var arrivalsByStop: [SavedStop.ID: [Arrival]] = [:]
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
                    CombinedArrivalRow(stop: row.stop, arrival: row.arrival)
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
        let result = await ArrivalsService.shared.arrivalsByStop(for: stops, limit: 8)
        arrivalsByStop = result
        error = nil
    }
}

private struct CombinedArrivalRow: View {
    let stop: SavedStop
    let arrival: Arrival

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
                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var rowSubtitle: String {
        let dir = stop.directionLabel
        if dir.isEmpty { return stop.stopName }
        return "\(dir) · \(stop.stopName)"
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
