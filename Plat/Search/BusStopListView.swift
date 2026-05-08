import SwiftUI
import PlatKit

struct BusStopListView: View {
    let line: String
    let directionID: Int
    let headsign: String

    @EnvironmentObject private var saved: SavedStopsStore
    @State private var query = ""

    private var stops: [BusStopRecord] {
        let all = BusStopCatalog.shared.stops(forLine: line, direction: directionID)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List(stops) { stop in
            let candidate = SavedStop.bus(
                stopCode: stop.code, stopName: stop.name, line: line,
                directionID: directionID, headsign: headsign,
                latitude: stop.lat, longitude: stop.lon
            )
            Button {
                toggle(candidate)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                        Text("Stop #\(stop.code)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if saved.contains(candidate) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Image(systemName: "plus.circle").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search stops")
        .navigationTitle(headsign.isEmpty ? line : headsign)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ stop: SavedStop) {
        if saved.contains(stop) { saved.remove(stop) } else { saved.save(stop) }
        Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
    }
}
