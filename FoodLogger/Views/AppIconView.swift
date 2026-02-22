import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Local color constants — matches brandX values in StyleGuide.swift
private let iconNavy     = Color(red: 0.106, green: 0.122, blue: 0.231)  // #1B1F3B brandPrimary
private let iconOffWhite = Color(red: 0.969, green: 0.953, blue: 0.933)  // #F7F3EE brandSurface
private let iconOrange   = Color(red: 1.000, green: 0.420, blue: 0.208)  // #FF6B35 brandAccent
private let iconAmber    = Color(red: 1.000, green: 0.702, blue: 0.278)  // #FFB347 brandWarm

/// SwiftUI representation of the app icon composition (1024×1024 design canvas).
/// Use `ImageRenderer` or Xcode's canvas to export the actual PNG asset.
@MainActor
struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background: deep navy with subtle radial gradient
            RadialGradient(
                colors: [
                    Color(red: 0.165, green: 0.188, blue: 0.318),
                    iconNavy
                ],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: 650
            )

            // Book assembly
            ZStack {
                // Shadow layer
                ZStack {
                    // Left page shadow
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 280, height: 200)
                        .rotationEffect(.degrees(-15))
                        .offset(x: -84, y: 15)
                        .blur(radius: 30)

                    // Right page shadow
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 280, height: 200)
                        .rotationEffect(.degrees(15))
                        .offset(x: 84, y: 15)
                        .blur(radius: 30)
                }

                // Left page
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconOffWhite)
                    .frame(width: 280, height: 200)
                    .rotationEffect(.degrees(-15))
                    .offset(x: -84, y: 0)

                // Right page
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconOffWhite)
                    .frame(width: 280, height: 200)
                    .rotationEffect(.degrees(15))
                    .offset(x: 84, y: 0)

                // Spine
                Rectangle()
                    .fill(iconOffWhite.opacity(0.85))
                    .frame(width: 3, height: 224)

                // Fork & knife symbol on spine
                Image(systemName: "fork.knife")
                    .font(.system(size: 120, weight: .medium))
                    .foregroundStyle(iconOrange)
            }
            .offset(y: -24)

            // Amber dot cluster — bottom-right quadrant
            ZStack {
                Circle().fill(iconAmber).frame(width: 16, height: 16).offset(x: 0, y: 0)
                Circle().fill(iconAmber).frame(width: 10, height: 10).offset(x: 18, y: -10)
                Circle().fill(iconAmber).frame(width: 7,  height: 7 ).offset(x: 10, y: 14)
            }
            .offset(x: 180, y: 200)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 224, style: .continuous))
    }
}

#Preview {
    AppIconView()
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
}
