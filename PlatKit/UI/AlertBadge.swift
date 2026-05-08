import SwiftUI

/// Color and icon mapping for a service-alert effect. Centralized so the
/// widget badge and the in-app alert row stay in sync.
public extension ServiceAlert.Effect {
    var tint: Color {
        switch self {
        case .noService:                                   return .red
        case .significantDelays, .reducedService, .detour: return .orange
        case .modifiedService, .accessibilityIssue,
             .stopMoved:                                   return .gray
        case .additionalService:                           return .green
        default:                                           return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .noService:           return "exclamationmark.octagon.fill"
        case .significantDelays,
             .reducedService:      return "clock.badge.exclamationmark.fill"
        case .detour:              return "arrow.triangle.branch"
        case .modifiedService:     return "exclamationmark.circle.fill"
        case .accessibilityIssue:  return "figure.roll"
        case .stopMoved:           return "mappin.and.ellipse"
        case .additionalService:   return "plus.circle.fill"
        default:                   return "info.circle.fill"
        }
    }
}

/// Compact alert pill for the home/lock widgets and saved-stop list rows.
public struct AlertPill: View {
    public let effect: ServiceAlert.Effect
    public var compact: Bool = false

    public init(effect: ServiceAlert.Effect, compact: Bool = false) {
        self.effect = effect; self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: effect.symbol)
                .font(.system(size: compact ? 9 : 10, weight: .bold))
            if !compact {
                Text(effect.shortLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(effect.tint))
    }
}

