import SwiftUI

// MARK: - Colors

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    static let brandPrimary = Color(hex: "#1B1F3B")  // deep navy
    static let brandAccent  = Color(hex: "#FF6B35")  // vivid orange
    static let brandWarm    = Color(hex: "#FFB347")  // amber
    static let brandSurface = Color(hex: "#F7F3EE")  // warm off-white
    static let brandSuccess = Color(hex: "#2ECC71")  // green
}

// MARK: - Typography

extension Font {
    static let appBody        = Font.system(.body,       design: .rounded, weight: .medium)
    static let appTitle       = Font.system(.title2,     design: .rounded, weight: .black)
    static let appCaption     = Font.system(.caption,    design: .rounded, weight: .regular)
    static let appHeadline    = Font.system(.headline,   design: .rounded, weight: .bold)
    static let appSubheadline = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let appDisplay     = Font.system(size: 34, weight: .black, design: .rounded)
}

// MARK: - Card Style

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark
                    ? Color(.secondarySystemGroupedBackground)
                    : Color.brandSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: Color.brandPrimary.opacity(colorScheme == .dark ? 0.3 : 0.08),
                radius: 10,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let symbol: String
    let message: String
    var subMessage: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.08))
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.brandAccent)
            }
            VStack(spacing: 6) {
                Text(message)
                    .font(.appHeadline)
                    .foregroundStyle(Color.brandPrimary)
                    .multilineTextAlignment(.center)
                if let sub = subMessage {
                    Text(sub)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }
}
