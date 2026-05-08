import WidgetKit
import SwiftUI
import AppIntents
import PlatKit

struct NearbyStopsWidget: Widget {
    let kind = "NearbyStopsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            NearbyStopsView(entry: entry)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("Plat")
        .description("Next arrival at the 3 closest saved locations.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct NearbyStopsView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let snap = entry.snapshot, !snap.groups.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header(updatedAt: snap.generatedAt)
                Divider().opacity(0.25).padding(.vertical, 4)
                VStack(spacing: 8) {
                    ForEach(snap.groups.prefix(3)) { group in
                        Link(destination: deepLink(for: group)) {
                            GroupRow(group: group)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.title2).foregroundStyle(.secondary)
                Text("Add stops in Plat")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(updatedAt: Date) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Next Arrivals")
                .font(.caption.weight(.heavy))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            Spacer()
            Text(updatedAt, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            Button(intent: RefreshArrivalsIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.thickMaterial))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GroupRow: View {
    let group: WidgetSnapshot.GroupSlot

    var body: some View {
        HStack(spacing: 10) {
            LineCluster(lines: group.lines, primary: group.nextArrival?.line)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.displayName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if !group.directionLabel.isEmpty {
                    Text(group.directionLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Minutes(arrival: group.nextArrival)
        }
    }
}

/// Stack of line bullets. The "primary" (line of the next arrival) is rendered
/// at full color; the others are smaller and dimmed so the eye reads the
/// primary line first.
private struct LineCluster: View {
    let lines: [String]
    let primary: String?

    private var ordered: [String] {
        guard let primary, lines.contains(primary) else { return lines }
        return [primary] + lines.filter { $0 != primary }
    }

    var body: some View {
        HStack(spacing: -6) {
            ForEach(Array(ordered.prefix(3).enumerated()), id: \.offset) { idx, line in
                LineBullet(line: line, size: idx == 0 ? .primary : .secondary)
                    .zIndex(Double(3 - idx))
            }
        }
        .frame(width: badgeWidth)
    }

    private var badgeWidth: CGFloat {
        switch min(ordered.count, 3) {
        case 1: return 32
        case 2: return 50
        default: return 64
        }
    }
}

private struct Minutes: View {
    let arrival: Arrival?

    var body: some View {
        if let arrival {
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(arrival.minutesAway())")
                        .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("m")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(arrival.arrivalTime, style: .time)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        } else {
            Text("—")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

enum Theme {
    static var background: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// Per-row deep link consumed by `RootView.handleDeepLink`. Group IDs may
/// contain reserved chars (the singleton case reuses the SavedStop.id format
/// `mode|stopID|line|directionCode`), so percent-encode the path component.
func deepLink(for group: WidgetSnapshot.GroupSlot) -> URL {
    let id = group.groupID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? group.groupID
    return URL(string: "plat://group/\(id)") ?? URL(string: "plat://group")!
}
