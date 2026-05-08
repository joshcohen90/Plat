import WidgetKit
import SwiftUI
import AppIntents
import PlatKit

/// Small home-screen widget. Shows the SINGLE closest saved location with its
/// next arrival. Designed for users who want one glance, not a list.
struct ClosestStopWidget: Widget {
    let kind = "ClosestStopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ClosestStopView(entry: entry)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("Closest Stop")
        .description("Next arrival at your closest saved location.")
        .supportedFamilies([.systemSmall])
    }
}

private struct ClosestStopView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let group = entry.snapshot?.groups.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let line = group.nextArrival?.line ?? group.lines.first {
                        LineBullet(line: line, size: .primary)
                    }
                    Spacer(minLength: 0)
                    Button(intent: RefreshArrivalsIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.thickMaterial))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                if let arrival = group.nextArrival {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(arrival.minutesAway())")
                            .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                        Text("min")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(arrival.arrivalTime, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                } else {
                    Text("—")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("No arrivals reported")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(group.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if !group.directionLabel.isEmpty {
                    Text(group.directionLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .widgetURL(deepLink(for: group))
        } else {
            VStack(spacing: 4) {
                Image(systemName: "tram.fill").font(.title3).foregroundStyle(.secondary)
                Text("Add a stop").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
