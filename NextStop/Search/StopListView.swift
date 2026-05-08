import SwiftUI
import NextStopKit

struct StopListView: View {
    let line: String
    @State private var query = ""

    private var stops: [TransitStop] {
        let all = StopCatalog.shared.stops(forLine: line)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List(stops) { stop in
            NavigationLink {
                DirectionPickerView(line: line, stop: stop)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.name).font(.body)
                    Text(stop.lines.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $query, prompt: "Search stops on \(line)")
        .navigationTitle("\(line) line")
    }
}
