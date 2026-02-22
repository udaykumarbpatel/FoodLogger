import SwiftUI

// MARK: - Typography

extension Font {
    static let appBody = Font.system(.body, design: .rounded)
    static let appTitle = Font.system(.title2, design: .rounded).bold()
    static let appCaption = Font.system(.caption, design: .rounded)
    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appSubheadline = Font.system(.subheadline, design: .rounded)
}

// MARK: - Card Style

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
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
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.appHeadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let sub = subMessage {
                Text(sub)
                    .font(.appCaption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
