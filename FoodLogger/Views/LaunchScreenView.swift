import SwiftUI

// Local color constants — matches brandX values in StyleGuide.swift
private let navyBackground = Color(red: 0.028, green: 0.043, blue: 0.094)  // ~#070B18 near-black navy
private let warmOffWhite   = Color(red: 0.969, green: 0.953, blue: 0.933)  // #F7F3EE brandSurface
private let vividOrange    = Color(red: 1.000, green: 0.420, blue: 0.208)  // #FF6B35 brandAccent

@MainActor
struct LaunchScreenView: View {
    let onComplete: () -> Void

    @State private var foodOpacity: Double = 0
    @State private var foodOffset: CGFloat = 24
    @State private var storyOpacity: Double = 0
    @State private var storyOffset: CGFloat = 24
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        ZStack {
            navyBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Typographic logo
                VStack(spacing: 4) {
                    Text("YOUR FOOD.")
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .foregroundStyle(warmOffWhite)
                        .opacity(foodOpacity)
                        .offset(y: foodOffset)

                    Text("YOUR STORY.")
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .italic()
                        .foregroundStyle(vividOrange)
                        .opacity(storyOpacity)
                        .offset(y: storyOffset)
                }
                .multilineTextAlignment(.center)

                Spacer().frame(height: 32)

                Text("No calories. No cloud. No compromise.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(warmOffWhite.opacity(0.45))
                    .opacity(subtitleOpacity)

                Spacer()
            }
        }
        .onAppear {
            // "YOUR FOOD." fades in and slides up
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                foodOpacity = 1.0
                foodOffset = 0
            }

            // "YOUR STORY." follows 0.15s later
            withAnimation(.easeOut(duration: 0.4).delay(0.30)) {
                storyOpacity = 1.0
                storyOffset = 0
            }

            // Subtitle fades in last
            withAnimation(.easeOut(duration: 0.35).delay(0.55)) {
                subtitleOpacity = 1.0
            }

            // Signal completion after 1.4s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                onComplete()
            }
        }
    }
}

#Preview {
    LaunchScreenView(onComplete: {})
}
