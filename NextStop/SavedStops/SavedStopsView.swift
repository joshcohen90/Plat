import SwiftUI
import NextStopKit

struct SavedStopsView: View {
    @EnvironmentObject private var saved: SavedStopsStore
    @EnvironmentObject private var location: LocationManager
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<SavedStop.ID> = []

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stops")
                .toolbar { toolbarContent }
                .environment(\.editMode, $editMode)
                .navigationDestination(for: SavedStop.self) { StopDetailView(stop: $0) }
                .refreshable {
                    await RefreshCoordinator.shared.refresh(reason: .pullToRefresh)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if saved.stops.isEmpty {
            ContentUnavailableView(
                "No saved stops",
                systemImage: "tram.fill",
                description: Text("Open **Add** to save subway and bus stops. The widget shows the next arrival at the **3 closest** locations you save.")
            )
        } else {
            List(selection: $selection) {
                ForEach(saved.resolvedGroups) { group in
                    GroupSection(group: group, distance: distance(to: group))
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if editMode == .active && selection.count >= 2 {
                    combineBar
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !saved.stops.isEmpty {
                EditButton()
            }
        }
    }

    private var combineBar: some View {
        HStack {
            Text("\(selection.count) selected").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button {
                let toCombine = saved.stops.filter { selection.contains($0.id) }
                saved.combine(toCombine)
                selection.removeAll()
                editMode = .inactive
                Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
            } label: {
                Label("Combine", systemImage: "rectangle.stack.badge.plus")
                    .labelStyle(.titleAndIcon)
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func distance(to group: ResolvedGroup) -> Double? {
        guard let here = location.lastLocation else { return nil }
        return here.distance(from: .init(latitude: group.coordinate.latitude, longitude: group.coordinate.longitude))
    }
}

private struct GroupSection: View {
    let group: ResolvedGroup
    let distance: Double?

    @EnvironmentObject private var saved: SavedStopsStore

    var body: some View {
        Section {
            ForEach(group.stops) { stop in
                NavigationLink(value: stop) {
                    SavedStopRow(stop: stop, showsChevron: false)
                }
                .tag(stop.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if group.isGrouped {
                        Button {
                            saved.ungroup(stop)
                            Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
                        } label: { Label("Ungroup", systemImage: "rectangle.split.2x1") }
                        .tint(.orange)
                    }
                    Button(role: .destructive) {
                        saved.remove(stop)
                        Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        } header: {
            GroupHeader(group: group, distance: distance)
        }
    }
}

private struct GroupHeader: View {
    let group: ResolvedGroup
    let distance: Double?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(group.displayName)
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
                .foregroundStyle(.primary)
            if group.isGrouped {
                Text("·").foregroundStyle(.secondary)
                Label("Combined", systemImage: "rectangle.stack.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            Spacer()
            if let distance {
                Text(formatDistance(distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1000)
    }
}

struct SavedStopRow: View {
    let stop: SavedStop
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(stop: stop)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.line + (stop.directionLabel.isEmpty ? "" : " · \(stop.directionLabel)"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(stop.stopName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One badge that picks the right visual per mode.
struct RouteBadge: View {
    let stop: SavedStop
    var body: some View {
        switch stop.mode {
        case .subway: LineBullet(line: stop.line)
        case .bus:    BusBadge(line: stop.line)
        }
    }
}
