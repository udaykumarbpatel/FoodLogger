import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Local color constants — matches brandX values in StyleGuide.swift
private let iconDeepNavy = Color(red: 0.028, green: 0.043, blue: 0.094)  // ~#070B18 near-black navy
private let iconCream    = Color(red: 0.969, green: 0.953, blue: 0.933)  // #F7F3EE brandSurface
private let iconOrange   = Color(red: 1.000, green: 0.420, blue: 0.208)  // #FF6B35 brandAccent

/// SwiftUI representation of the app icon composition (1024×1024 design canvas).
/// iOS applies its own corner-radius mask, so this renders as a full square.
/// Use the "Export App Icon" button in Settings (DEBUG builds) to generate the PNG.
@MainActor
struct AppIconView: View {
    var body: some View {
        ZStack {
            iconDeepNavy

            VStack(spacing: 6) {
                Text("YOUR FOOD.")
                    .font(.system(size: 148, weight: .black, design: .serif))
                    .foregroundStyle(iconCream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)

                Text("YOUR STORY.")
                    .font(.system(size: 148, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(iconOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 48)
        }
        .frame(width: 1024, height: 1024)
        // No .clipShape — iOS applies its own mask; the PNG must be a full square.
    }
}

#Preview {
    AppIconView()
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
}
