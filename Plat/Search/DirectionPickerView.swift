import SwiftUI
import PlatKit

/// Subway direction picker: TransitStop has both directions on one parent station.
/// User taps a direction → SavedStop is created and stored.
struct DirectionPickerView: View {
    let line: String
    let stop: TransitStop

    @EnvironmentObject private var saved: SavedStopsStore

    var body: some View {
        List {
            Section("Direction") {
                ForEach(Direction.allCases, id: \.self) { dir in
                    let candidate = SavedStop.subway(stop: stop, line: line, direction: dir)
                    Button {
                        toggle(candidate)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dir.label(forLine: line)).foregroundStyle(.primary)
                                Text(stop.name).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if saved.contains(candidate) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(line) at \(stop.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ stop: SavedStop) {
        if saved.contains(stop) { saved.remove(stop) } else { saved.save(stop) }
        Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
    }
}

/// Bus direction picker: pick a headsign first (bus stops are per-direction).
struct BusDirectionPickerView: View {
    let line: String

    private var directions: [(directionID: Int, headsign: String)] {
        BusStopCatalog.shared.directions(forLine: line)
    }

    var body: some View {
        List(directions, id: \.directionID) { d in
            NavigationLink(value: BusDirectionRoute(line: line, directionID: d.directionID, headsign: d.headsign)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.headsign.isEmpty ? "Direction \(d.directionID)" : d.headsign)
                    Text("\(BusStopCatalog.shared.stops(forLine: line, direction: d.directionID).count) stops")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("\(line) — direction")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: BusDirectionRoute.self) { r in
            BusStopListView(line: r.line, directionID: r.directionID, headsign: r.headsign)
        }
    }
}

struct BusDirectionRoute: Hashable {
    let line: String
    let directionID: Int
    let headsign: String
}
