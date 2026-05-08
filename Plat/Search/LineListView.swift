import SwiftUI
import PlatKit

struct LineListView: View {
    @State private var mode: TransitMode = .subway

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(TransitMode.allCases, id: \.self) { m in
                        Label(m.displayName, systemImage: m.systemImage).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)

                switch mode {
                case .subway: SubwayLineList()
                case .bus:    BusLineList()
                }
            }
            .navigationTitle("Add a stop")
        }
    }
}

private struct SubwayLineList: View {
    private let lines = StopCatalog.shared.allLines

    var body: some View {
        List(lines, id: \.self) { line in
            NavigationLink(value: SubwayRoute(line: line)) {
                HStack(spacing: 12) {
                    LineBullet(line: line, size: .large)
                    Text("\(StopCatalog.shared.stops(forLine: line).count) stops")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationDestination(for: SubwayRoute.self) { route in
            StopListView(line: route.line)
        }
    }
}

private struct BusLineList: View {
    @State private var query = ""

    /// Treat the query as a stop-code lookup when it's mostly digits and ≥3 chars.
    private var isStopCodeQuery: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        return trimmed.allSatisfy(\.isNumber)
    }

    var body: some View {
        Group {
            if isStopCodeQuery {
                BusStopCodeResults(query: query)
            } else {
                BusRouteResults(query: query)
            }
        }
        .searchable(text: $query, prompt: "Find a route or stop # (e.g. M15 or 400069)")
        .navigationDestination(for: BusRoute.self) { route in
            BusDirectionPickerView(line: route.line)
        }
    }
}

private struct BusRouteResults: View {
    let query: String

    private var lines: [String] {
        let all = BusStopCatalog.shared.allLines
        let q = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.uppercased().contains(q) }
    }

    var body: some View {
        if lines.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(lines, id: \.self) { line in
                NavigationLink(value: BusRoute(line: line)) {
                    HStack(spacing: 12) {
                        LineBullet(line: line, size: .large)
                        let dirs = BusStopCatalog.shared.directions(forLine: line)
                        Text(dirs.count == 2 ? "Both directions" : "\(dirs.count) direction")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                }
            }
        }
    }
}

private struct BusStopCodeResults: View {
    let query: String
    @EnvironmentObject private var saved: SavedStopsStore

    private var grouped: [(code: String, name: String, rows: [BusStopRecord])] {
        let digits = query.filter(\.isNumber)
        let matches = BusStopCatalog.shared.records(matchingCodePrefix: digits)
        var byCode: [String: [BusStopRecord]] = [:]
        for r in matches { byCode[r.code, default: []].append(r) }
        return byCode.map { (code, rows) in
            (code: code, name: rows.first?.name ?? "",
             rows: rows.sorted { ($0.line, $0.directionID) < ($1.line, $1.directionID) })
        }.sorted { $0.code < $1.code }
    }

    var body: some View {
        if grouped.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(grouped, id: \.code) { group in
                Section {
                    ForEach(group.rows) { row in
                        let candidate = SavedStop.bus(
                            stopCode: row.code, stopName: row.name, line: row.line,
                            directionID: row.directionID, headsign: row.headsign,
                            latitude: row.lat, longitude: row.lon
                        )
                        Button {
                            if saved.contains(candidate) { saved.remove(candidate) } else { saved.save(candidate) }
                            Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
                        } label: {
                            HStack {
                                LineBullet(line: row.line)
                                Text(row.headsign.isEmpty ? "Direction \(row.directionID)" : row.headsign)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: saved.contains(candidate) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(saved.contains(candidate) ? .green : .secondary)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name).font(.subheadline.weight(.semibold)).textCase(nil)
                        Text("Stop #\(group.code)")
                            .font(.caption).foregroundStyle(.secondary).textCase(nil)
                    }
                }
            }
        }
    }
}

// Wrapper types so SwiftUI's navigationDestination can disambiguate.
struct SubwayRoute: Hashable { let line: String }
struct BusRoute: Hashable { let line: String }

// LineBullet, BusBadge replaced by PlatKit.LineBullet (which handles both modes).
// Use `LineBullet(line: ..., size: .large)` in pickers.
typealias BusBadge = LineBullet
