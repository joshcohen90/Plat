import WidgetKit
import SwiftUI
import PlatKit

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

        content(group: group, arrival: arrival)
            .widgetURL(group.map { deepLink(for: $0) })
    }

    @ViewBuilder
    private func content(group: WidgetSnapshot.GroupSlot?, arrival: Arrival?) -> some View {
        switch family {
        case .accessoryInline:
            if let group, let arrival {
                if group.alertEffect != nil {
                    Text("⚠︎ \(arrival.line) \(arrival.minutesAway())m · \(group.displayName)")
                } else {
                    Text("\(arrival.line) \(arrival.minutesAway())m · \(group.displayName)")
                }
            } else {
                Text("Plat")
            }

        case .accessoryCircular:
            // Tight 16pt circular slot. Show line + minutes; stop name doesn't fit.
            if let arrival {
                VStack(spacing: -2) {
                    Text(arrival.line)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                    Text("\(arrival.minutesAway())")
                        .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                    Text("min")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .widgetAccentable()
            } else {
                Image(systemName: "tram.fill")
            }

        default:
            // Rectangular — lead with stop name + line, then big minutes.
            // Earlier layout buried the stop name under the minutes; users
            // didn't notice it.
            if let group, let arrival {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(arrival.line)
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().stroke(lineWidth: 1.4))
                        Text(group.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if group.alertEffect != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(arrival.minutesAway())")
                            .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                        Text("min")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        if !group.directionLabel.isEmpty {
                            Text("· \(group.directionLabel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                .widgetAccentable()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plat").font(.caption.weight(.heavy))
                    Text("Add stops in app").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
