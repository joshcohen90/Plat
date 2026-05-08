import SwiftUI
import PlatKit

struct StopDetailView: View {
    let stop: SavedStop
    @State private var arrivals: [Arrival] = []
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

            Section("Next arrivals") {
                if loading && arrivals.isEmpty {
                    ProgressView()
                } else if let error {
                    Text(error).foregroundStyle(.red)
                } else if arrivals.isEmpty {
                    Text("No arrivals reported.").foregroundStyle(.secondary)
                } else {
                    ForEach(arrivals.prefix(8), id: \.self) { arr in
                        HStack {
                            Group {
                                switch arr.mode {
                                case .subway: LineBullet(line: arr.line)
                                case .bus:    BusBadge(line: arr.line)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("\(arr.minutesAway()) min")
                                    .font(.body.monospacedDigit())
                                Text(arr.arrivalTime, style: .time)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
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
        do {
            arrivals = try await ArrivalsService.shared.arrivals(for: stop)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
