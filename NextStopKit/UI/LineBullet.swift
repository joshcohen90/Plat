import SwiftUI

public enum BulletSize: Sendable {
    case primary, secondary, large

    public var diameter: CGFloat {
        switch self { case .large: 40; case .primary: 32; case .secondary: 22 }
    }
    public var fontSize: CGFloat {
        switch self { case .large: 20; case .primary: 16; case .secondary: 11 }
    }
}

/// MTA-style route bullet. Handles both subway (circle) and bus (rounded rect)
/// from a single line code via a small heuristic.
public struct LineBullet: View {
    public let line: String
    public let size: BulletSize

    public init(line: String, size: BulletSize = .primary) {
        self.line = line; self.size = size
    }

    public var body: some View {
        if isBus {
            Text(line)
                .font(.system(size: size.fontSize - 2, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: size.diameter + 4, minHeight: size.diameter)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(line.hasSuffix("+") ? Color(red: 0, green: 0.45, blue: 0.7) : Color.blue.opacity(0.85))
                )
        } else {
            Text(line)
                .font(.system(size: size.fontSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size.diameter, height: size.diameter)
                .background(Circle().fill(LineColor.color(for: line)))
        }
    }

    /// Heuristic — subway codes are 1-char (1..7, A..Z) plus 6X / 7X / SI / SIR.
    /// Anything else (M15, B41, M15+, BX12+, S40, ...) is a bus.
    private var isBus: Bool {
        switch line {
        case "6X","7X","SI","SIR": return false
        default:
            guard let first = line.first else { return false }
            if first.isNumber { return false }    // 1..7
            if line.count == 1 { return false }   // A, C, E, ...
            return true
        }
    }
}

public enum LineColor {
    public static func color(for line: String) -> Color {
        switch line {
        case "1","2","3":          return Color(red: 0.93, green: 0.20, blue: 0.20)
        case "4","5","6","6X":     return Color(red: 0.00, green: 0.60, blue: 0.36)
        case "7","7X":             return Color(red: 0.71, green: 0.20, blue: 0.55)
        case "A","C","E":          return Color(red: 0.00, green: 0.40, blue: 0.79)
        case "B","D","F","M":      return Color(red: 0.94, green: 0.55, blue: 0.20)
        case "G":                  return Color(red: 0.42, green: 0.74, blue: 0.20)
        case "J","Z":              return Color(red: 0.60, green: 0.40, blue: 0.18)
        case "L":                  return Color(red: 0.65, green: 0.65, blue: 0.66)
        case "N","Q","R","W":      return Color(red: 0.99, green: 0.81, blue: 0.13)
        case "SI","SIR":           return Color(red: 0.00, green: 0.45, blue: 0.70)
        default: return .secondary
        }
    }
}
