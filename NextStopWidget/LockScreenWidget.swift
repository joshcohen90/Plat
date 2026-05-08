import WidgetKit
import SwiftUI
import NextStopKit

struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next Arrival")
        .description("Closest location's next arrival.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        let group = entry.snapshot?.groups.first
        let arrival = group?.nextArrival

        switch family {
        case .accessoryInline:
            if let group, let arrival {
                Text("\(arrival.line) \(arrival.minutesAway())m · \(group.displayName)")
            } else {
                Text("NextStop")
            }

        case .accessoryCircular:
            if let arrival {
                Gauge(value: 0) { Text(arrival.line).font(.caption2.weight(.heavy)) }
                    currentValueLabel: {
                        Text("\(arrival.minutesAway())")
                            .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
            } else {
                Image(systemName: "tram.fill")
            }

        default:
            VStack(alignment: .leading, spacing: 1) {
                if let group, let arrival {
                    HStack(spacing: 6) {
                        Text(arrival.line)
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().stroke(lineWidth: 1.2))
                        Text("\(arrival.minutesAway())")
                            .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                        Text("min").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text(group.displayName)
                        .font(.caption2.weight(.medium)).lineLimit(1)
                    if !group.directionLabel.isEmpty {
                        Text(group.directionLabel)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("NextStop").font(.caption.weight(.heavy))
                    Text("Add stops in app").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
