import SwiftUI
import Charts

// MARK: - WeeklyRecapView

struct WeeklyRecapView: View {
    let summary: WeeklySummary
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    private let totalPages = 6

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                HeroPage(summary: summary)
                    .tag(0)
                StatsPage(summary: summary)
                    .tag(1)
                TopFoodPage(summary: summary)
                    .tag(2)
                CategoryPage(summary: summary)
                    .tag(3)
                ConsistencyPage(summary: summary)
                    .tag(4)
                SharePage(summary: summary, dismiss: { dismiss() })
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Custom dot indicator
            PageDots(currentPage: currentPage, totalPages: totalPages)
                .padding(.bottom, 20)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Page Dots

private struct PageDots: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                    .animation(.spring(duration: 0.3), value: currentPage)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

// MARK: - Page 1: Hero

private struct HeroPage: View {
    let summary: WeeklySummary
    @State private var appeared = false

    private var weekRangeText: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: summary.weekStartDate)!
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(summary.weekStartDate.formatted(fmt)) – \(end.formatted(fmt))"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Your Week in Review")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityAddTraits(.isHeader)

                    Text(weekRangeText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                Text(summary.headline)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(.easeOut(duration: 0.6).delay(0.25), value: appeared)
                    .accessibilityLabel("Headline: \(summary.headline)")

                Text(summary.subheadline)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
                    .accessibilityLabel("Summary: \(summary.subheadline)")

                Spacer()

                Text("Swipe to explore →")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 80)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.7), value: appeared)
            }
            .padding()
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 2: Stats Grid

private struct StatsPage: View {
    let summary: WeeklySummary
    @State private var appeared = false

    private var bestDayName: String {
        guard let day = summary.bestDay else { return "—" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("This Week")
                    .font(.system(.title2, design: .rounded).bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatTile(
                        icon: "fork.knife",
                        value: "\(summary.totalEntries)",
                        label: "Meals Logged",
                        color: .accentColor,
                        delay: 0.0,
                        appeared: appeared
                    )
                    StatTile(
                        icon: "flame.fill",
                        value: "\(summary.currentStreak)",
                        label: "Day Streak",
                        color: .orange,
                        delay: 0.1,
                        appeared: appeared
                    )
                    StatTile(
                        icon: "sparkles",
                        value: "\(summary.uniqueFoodsCount)",
                        label: "Unique Foods",
                        color: .purple,
                        delay: 0.2,
                        appeared: appeared
                    )
                    StatTile(
                        icon: "calendar",
                        value: bestDayName,
                        label: "Best Day",
                        color: .green,
                        delay: 0.3,
                        appeared: appeared
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear { appeared = true }
    }
}

private struct StatTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let delay: Double
    let appeared: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(.title, design: .rounded).bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.8)
        .animation(.spring(duration: 0.5, bounce: 0.3).delay(delay), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Page 3: Top Food

private struct TopFoodPage: View {
    let summary: WeeklySummary
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if let food = summary.topFoodItem, summary.topFoodCount > 0 {
                    VStack(spacing: 16) {
                        // Layered SF Symbol illustration
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 140, height: 140)
                            Circle()
                                .fill(Color.accentColor.opacity(0.08))
                                .frame(width: 110, height: 110)
                            Image(systemName: summary.topCategory?.icon ?? "fork.knife")
                                .font(.system(size: 52))
                                .foregroundStyle(Color.accentColor)
                        }
                        .accessibilityHidden(true)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .animation(.spring(duration: 0.6, bounce: 0.4), value: appeared)

                        Text(food.capitalized)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                        Text("You had this \(summary.topFoodCount) time\(summary.topFoodCount == 1 ? "" : "s") this week")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Top food: \(food), logged \(summary.topFoodCount) times")
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .animation(.spring(duration: 0.6, bounce: 0.4), value: appeared)

                        Text("You tried \(summary.uniqueFoodsCount) different things this week 🌟")
                            .font(.system(.title2, design: .rounded).bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 4: Category Breakdown

private struct CategoryPage: View {
    let summary: WeeklySummary
    @State private var appeared = false

    private var categoryData: [(category: MealCategory, count: Int)] {
        summary.categoryBreakdown
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("What You Ate")
                    .font(.system(.title2, design: .rounded).bold())
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .accessibilityAddTraits(.isHeader)

                if categoryData.isEmpty {
                    Spacer()
                    EmptyStateView(symbol: "tag", message: "No categories tagged this week")
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    Chart(categoryData, id: \.category) { item in
                        BarMark(
                            x: .value("Count", appeared ? item.count : 0),
                            y: .value("Category", item.category.displayName)
                        )
                        .foregroundStyle(item.category.color)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("\(item.count)")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let name = value.as(String.self) {
                                    Text(name)
                                        .font(.system(.caption, design: .rounded))
                                }
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.7), value: appeared)
                    .frame(maxHeight: 280)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Category breakdown chart")
                }

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }
}

// MARK: - Page 5: Consistency

private struct ConsistencyPage: View {
    let summary: WeeklySummary
    @State private var appeared = false
    @State private var showConfetti = false

    private var isPerfectWeek: Bool { summary.missedDays == 0 }

    private var daysLogged: Int { 7 - summary.missedDays }

    private var sortedDays: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset -> (Date, Int)? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: summary.weekStartDate) else { return nil }
            return (day, summary.dailyEntryCounts[day] ?? 0)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 28) {
                Text("Consistency")
                    .font(.system(.title2, design: .rounded).bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .accessibilityAddTraits(.isHeader)

                // 7-day strip
                HStack(spacing: 8) {
                    ForEach(Array(sortedDays.enumerated()), id: \.offset) { index, dayData in
                        DayCircle(
                            date: dayData.date,
                            hasEntries: dayData.count > 0,
                            delay: Double(index) * 0.07,
                            appeared: appeared
                        )
                    }
                }
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Days logged this week")

                // Summary text
                VStack(spacing: 8) {
                    Text("You logged on \(daysLogged)/7 days")
                        .font(.system(.headline, design: .rounded))

                    if isPerfectWeek {
                        Text("Perfect week! 🎉")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(Color.accentColor)
                    }

                    // vs last week
                    if summary.vsLastWeek != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: summary.vsLastWeek > 0 ? "arrow.up" : "arrow.down")
                            Text("\(abs(summary.vsLastWeek)) \(abs(summary.vsLastWeek) == 1 ? "meal" : "meals") \(summary.vsLastWeek > 0 ? "more" : "fewer") than last week")
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(summary.vsLastWeek > 0 ? .green : .red)
                        .accessibilityLabel(summary.vsLastWeek > 0
                            ? "\(summary.vsLastWeek) more meals than last week"
                            : "\(abs(summary.vsLastWeek)) fewer meals than last week")
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)

                Spacer()
            }
        }
        .onAppear {
            appeared = true
            if isPerfectWeek {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showConfetti = true
                }
            }
        }
    }
}

private struct DayCircle: View {
    let date: Date
    let hasEntries: Bool
    let delay: Double
    let appeared: Bool

    private var dayLetter: String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayLetter)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            Circle()
                .fill(hasEntries ? Color.accentColor : Color(.systemFill))
                .frame(width: 36, height: 36)
                .overlay {
                    if hasEntries {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.3)
                .animation(.spring(duration: 0.4, bounce: 0.5).delay(delay), value: appeared)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(dayLetter): \(hasEntries ? "logged" : "no entries")")
    }
}

// MARK: - Confetti (Canvas-based, no third party)

private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animating = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let elapsed = now - particle.startTime
                    guard elapsed >= 0 else { continue }
                    let progress = min(elapsed / 2.5, 1.0)
                    let x = particle.x * size.width + particle.vx * elapsed * 60
                    let y = -20 + particle.vy * elapsed * 60 + 0.5 * 200 * elapsed * elapsed
                    let opacity = progress < 0.8 ? 1.0 : (1.0 - progress) / 0.2

                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 8, height: 8)),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            let now = Date.timeIntervalSinceReferenceDate
            particles = (0..<80).map { i in
                ConfettiParticle(
                    x: Double.random(in: 0...1),
                    vx: Double.random(in: -0.05...0.05),
                    vy: Double.random(in: 0.1...0.4),
                    color: colors.randomElement()!,
                    startTime: now + Double(i) * 0.02
                )
            }
        }
    }
}

private struct ConfettiParticle {
    let x: Double
    let vx: Double
    let vy: Double
    let color: Color
    let startTime: TimeInterval
}

// MARK: - Page 6: Share

private struct SharePage: View {
    let summary: WeeklySummary
    let dismiss: () -> Void
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    private var weekRangeText: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: summary.weekStartDate)!
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(summary.weekStartDate.formatted(fmt)) – \(end.formatted(fmt))"
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Share Your Week")
                    .font(.system(.title2, design: .rounded).bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .accessibilityAddTraits(.isHeader)

                // Share card preview
                ShareCardView(summary: summary, weekRangeText: weekRangeText)
                    .padding(.horizontal, 24)
                    .id("shareCard")

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        renderAndShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .accessibilityLabel("Share your weekly recap")

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .accessibilityLabel("Close weekly recap")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheetWrapper(items: [image])
            }
        }
    }

    @MainActor
    private func renderAndShare() {
        let card = ShareCardView(summary: summary, weekRangeText: weekRangeText)
            .frame(width: 340, height: 200)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        shareImage = renderer.uiImage
        showShareSheet = shareImage != nil
    }
}

private struct ShareCardView: View {
    let summary: WeeklySummary
    let weekRangeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("FoodLogger")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(summary.headline)
                .font(.system(.title3, design: .rounded).bold())
                .multilineTextAlignment(.leading)
                .accessibilityLabel(summary.headline)

            HStack(spacing: 16) {
                if summary.currentStreak > 0 {
                    Label("\(summary.currentStreak) day streak", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
                Label(weekRangeText, systemImage: "calendar")
                    .foregroundStyle(.secondary)
            }
            .font(.system(.caption, design: .rounded))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Share Sheet Wrapper

private struct ShareSheetWrapper: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
