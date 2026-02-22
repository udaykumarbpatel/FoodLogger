import SwiftUI

// Local color constants — matches brandX values in StyleGuide.swift
private let navyBackground = Color(red: 0.106, green: 0.122, blue: 0.231)   // #1B1F3B brandPrimary
private let warmOffWhite   = Color(red: 0.969, green: 0.953, blue: 0.933)   // #F7F3EE brandSurface
private let vividOrange    = Color(red: 1.000, green: 0.420, blue: 0.208)   // #FF6B35 brandAccent
private let amber          = Color(red: 1.000, green: 0.702, blue: 0.278)   // #FFB347 brandWarm

@MainActor
struct LaunchScreenView: View {
    let onComplete: () -> Void

    @State private var bookScale: CGFloat = 0.3
    @State private var bookOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var taglineOpacity: Double = 0

    var body: some View {
        ZStack {
            navyBackground
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Book + fork motif
                ZStack {
                    // Left page — rotated outward (counter-clockwise)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(warmOffWhite)
                        .frame(width: 80, height: 100)
                        .rotationEffect(.degrees(-12))
                        .offset(x: -28, y: 0)
                        .opacity(bookOpacity)

                    // Right page — rotated outward (clockwise)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(warmOffWhite)
                        .frame(width: 80, height: 100)
                        .rotationEffect(.degrees(12))
                        .offset(x: 28, y: 0)
                        .opacity(bookOpacity)

                    // Book spine — vertical center line
                    Rectangle()
                        .fill(warmOffWhite.opacity(0.85))
                        .frame(width: 3, height: 108)
                        .opacity(bookOpacity)

                    // Fork and knife SF Symbol — centered on spine
                    Image(systemName: "fork.knife")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(vividOrange)
                        .opacity(bookOpacity)
                }
                .scaleEffect(bookScale)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

                // Text stack
                VStack(spacing: 8) {
                    Text("FoodLogger")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(textOpacity)
                        .offset(y: textOffset)

                    Text("Your food. Your story.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(amber)
                        .opacity(taglineOpacity)
                }
            }
        }
        .onAppear {
            // Book scale-up spring animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                bookScale = 1.0
            }

            // Book opacity fade-in with 0.2s delay
            withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
                bookOpacity = 1.0
            }

            // App name fade in + upward slide after 0.3s
            withAnimation(.easeOut(duration: 0.45).delay(0.3)) {
                textOpacity = 1.0
                textOffset = 0
            }

            // Tagline fade in after 0.5s
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                taglineOpacity = 1.0
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
