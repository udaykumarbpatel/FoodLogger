import SwiftUI

// MARK: - Brand Color Helpers (local fallbacks; StyleGuide.swift may define authoritative versions)

// Color(hex:) initializer — fileprivate to avoid duplicate-symbol conflicts with StyleGuide
fileprivate extension Color {
    init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double(rgb         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// Brand color constants — fileprivate so they shadow/coexist with any module-level extensions
fileprivate let _brandPrimary = Color(hexString: "#1B1F3B")   // deep navy
fileprivate let _brandAccent  = Color(hexString: "#FF6B35")   // vivid orange
fileprivate let _brandWarm    = Color(hexString: "#FFB347")   // amber
fileprivate let _brandSurface = Color(hexString: "#F7F3EE")   // warm off-white

// MARK: - OnboardingView

@MainActor
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                OnboardingPage1()
                    .tag(0)
                OnboardingPage2()
                    .tag(1)
                OnboardingPage3()
                    .tag(2)
                OnboardingPage4(onComplete: onComplete)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Bottom chrome overlay (skip / indicator / continue)
            VStack(spacing: 0) {
                Spacer()
                bottomChrome
            }
            .ignoresSafeArea(edges: .bottom)

            // Skip button top-right (pages 0–2 only)
            if currentPage < 3 {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            UserDefaults.standard.set(true, forKey: "onboardingComplete")
                            onComplete()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.top, 56)
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Bottom chrome

    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: 20) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? _brandAccent : Color.white.opacity(0.4))
                        .frame(width: i == currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Continue button (pages 0–2 only; page 3 has its own "Get Started")
            if currentPage < 3 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage += 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(_brandAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 32)
                }
            } else {
                // Spacer placeholder on page 3 so chrome layout is consistent
                // (page 3 has its own Get Started button in its body)
                Color.clear.frame(height: 52)
            }
        }
        .padding(.bottom, 48)
    }
}

// MARK: - Page 1: Welcome

@MainActor
private struct OnboardingPage1: View {
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            _brandPrimary
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Book+fork icon
                ZStack {
                    // Left page of book
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 64, height: 80)
                        .rotationEffect(.degrees(-12))
                        .offset(x: -20, y: 0)

                    // Right page of book
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 64, height: 80)
                        .rotationEffect(.degrees(12))
                        .offset(x: 20, y: 0)

                    // Fork & knife overlay on spine
                    Image(systemName: "fork.knife")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(_brandAccent)
                }
                .frame(width: 120, height: 100)
                .overlay(alignment: .top) {
                    // Animated ambient dots above the book
                    Canvas { context, size in
                        let positions: [(CGFloat, CGFloat, CGFloat)] = [
                            (0.1, 0.15, 6), (0.3, 0.05, 4), (0.5, 0.20, 5),
                            (0.7, 0.08, 7), (0.9, 0.18, 4), (0.2, 0.30, 5),
                            (0.6, 0.35, 6), (0.85, 0.28, 4)
                        ]
                        for (relX, relY, diameter) in positions {
                            let x = relX * size.width
                            let y = relY * size.height + floatOffset * 3
                            let rect = CGRect(
                                x: x - diameter / 2,
                                y: y - diameter / 2,
                                width: diameter,
                                height: diameter
                            )
                            context.fill(Path(ellipseIn: rect), with: .color(_brandWarm.opacity(0.7)))
                        }
                    }
                    .frame(width: 160, height: 60)
                    .offset(y: -60)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: floatOffset)
                }
                .onAppear {
                    floatOffset = 1.0
                }

                // Headline
                Text("Welcome to FoodLogger")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text("Your private food diary. No calories. No judgment.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(_brandWarm)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Page 2: Log Anything

@MainActor
private struct OnboardingPage2: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [_brandPrimary, Color(hexString: "#2D1B6E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                // Fanned card stack
                ZStack {
                    // Card 3 — photo (back right)
                    LogModeCard(icon: "camera.fill", caption: "Snap it")
                        .rotationEffect(.degrees(18))
                        .offset(x: 60, y: 10)

                    // Card 1 — text (back left)
                    LogModeCard(icon: "pencil.and.list.clipboard", caption: "Type it")
                        .rotationEffect(.degrees(-18))
                        .offset(x: -60, y: 10)

                    // Card 2 — voice (center, front)
                    LogModeCard(icon: "mic.fill", caption: "Say it")
                }
                .frame(height: 120)

                // Description
                Text("Log by typing, talking,\nor snapping a photo")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Log Mode Card (used by Page 2)

@MainActor
private struct LogModeCard: View {
    let icon: String
    let caption: String

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            .frame(width: 140, height: 90)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(_brandAccent)
                    Text(caption)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(_brandPrimary)
                }
            }
    }
}

// MARK: - Page 3: See Your Patterns

@MainActor
private struct OnboardingPage3: View {
    // Bar heights (7 bars, varying 20–60 pt)
    private let barHeights: [CGFloat] = [20, 28, 40, 35, 52, 45, 60]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [_brandPrimary, Color(hexString: "#0D3B4A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                // Mini bar chart preview
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                            let opacity = 0.4 + 0.6 * (Double(index) / Double(barHeights.count - 1))
                            Capsule()
                                .fill(_brandAccent.opacity(opacity))
                                .frame(width: 12, height: height)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Streak badge
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(_brandAccent)
                        Text("7")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("day streak")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(_brandPrimary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Description
                Text("Discover what you eat, when you eat it, and how consistent you are")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Page 4: Private by Design

@MainActor
private struct OnboardingPage4: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [_brandPrimary, Color(hexString: "#0A2E1A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(_brandWarm)

                Text("Everything stays on your device. Always.")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("No account. No cloud. No tracking.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(_brandWarm)
                    .multilineTextAlignment(.center)

                Spacer()

                // Get Started button
                Button {
                    UserDefaults.standard.set(true, forKey: "onboardingComplete")
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(_brandAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 130) // leaves room for the bottom chrome overlay
            }
        }
    }
}
