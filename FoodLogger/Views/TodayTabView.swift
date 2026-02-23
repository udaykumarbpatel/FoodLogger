import SwiftUI
import SwiftData

struct TodayTabView: View {
    @Query private var allEntries: [FoodEntry]
    private let streakService = StreakService()

    /// Owned here so the banner reacts synchronously to page swipes.
    @State private var selectedIndex: Int = DayLogView.todayIndex

    // MARK: - Computed

    private var isViewingToday: Bool {
        selectedIndex == DayLogView.todayIndex
    }

    private var viewedDate: Date {
        let offset = selectedIndex - DayLogView.todayIndex
        return Calendar.current.date(
            byAdding: .day,
            value: offset,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Calendar.current.startOfDay(for: Date())
    }

    /// Day-of-month as a string ("22") — used as the ghost watermark.
    private var dayNumber: String {
        String(Calendar.current.component(.day, from: viewedDate))
    }

    private var streakInfo: StreakService.StreakInfo {
        streakService.compute(from: allEntries)
    }

    private var viewedDayEntryCount: Int {
        let start = Calendar.current.startOfDay(for: viewedDate)
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return allEntries.filter { $0.date >= start && $0.date < end }.count
    }

    // MARK: - Context label (greeting today / relative label past)

    private var contextLabel: String {
        if isViewingToday {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:  return "Good morning"
            case 12..<17: return "Good afternoon"
            default:      return "Good evening"
            }
        } else {
            let days = Calendar.current.dateComponents(
                [.day],
                from: viewedDate,
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? 0
            switch days {
            case 1:      return "Yesterday"
            case 2..<7:  return "\(days) days ago"
            case 7:      return "One week ago"
            case 8..<14: return "\(days) days ago"
            case 14:     return "Two weeks ago"
            default:
                let weeks = days / 7
                return days % 7 == 0 ? "\(weeks) weeks ago" : "\(days) days ago"
            }
        }
    }

    private var flameColor: Color {
        switch streakInfo.count {
        case 0..<7:  return Color.brandWarm
        case 7..<14: return .orange
        default:     return .red
        }
    }

    private var entryCountLabel: String {
        let n    = viewedDayEntryCount
        let noun = n == 1 ? "entry" : "entries"
        return isViewingToday ? "\(n) \(noun) today" : "\(n) \(noun) that day"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            DayLogView(selectedIndex: $selectedIndex)
                .safeAreaInset(edge: .top, spacing: 0) {
                    bannerView
                }
        }
    }

    // MARK: - Banner

    private var bannerView: some View {
        VStack(spacing: 0) {

            // ── Editorial masthead strip ──────────────────────────────────────
            Rectangle()
                .fill(Color.brandAccent)
                .frame(height: 3)

            // ── Main banner area ──────────────────────────────────────────────
            // Content drives the height; decorative layers are overlays so they
            // don't inflate the ZStack's intrinsic size.
            HStack(alignment: .center, spacing: 16) {

                // Left: context → date → entry count
                VStack(alignment: .leading, spacing: 4) {
                    Text(contextLabel.uppercased())
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .kerning(1.6)
                        .foregroundStyle(
                            isViewingToday
                                ? Color.brandWarm.opacity(0.90)
                                : Color.brandAccent.opacity(0.72)
                        )

                    Text(viewedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(
                            isViewingToday
                                ? Color.brandSurface
                                : Color.brandSurface.opacity(0.62)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(entryCountLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.brandSurface.opacity(0.38))
                }

                Spacer(minLength: 0)

                // Right: streak metric (hidden when streak = 0)
                if streakInfo.count > 0 {
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(flameColor)
                        Text("\(streakInfo.count)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Color.brandSurface)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background {
                // Background layers — don't affect content sizing
                ZStack {
                    Color.brandVoid
                    LinearGradient(
                        colors: [Color.brandPrimary.opacity(0.50), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Ghost day-number watermark — bleeds off the right/bottom edge
                Text(dayNumber)
                    .font(.system(size: 112, weight: .black, design: .serif))
                    .foregroundStyle(Color.brandSurface.opacity(0.065))
                    .offset(x: 14, y: 16)
                    .allowsHitTesting(false)
                    .clipped()
            }
            .clipped()

            // ── Bottom journal rule ───────────────────────────────────────────
            Rectangle()
                .fill(
                    isViewingToday
                        ? Color.brandAccent.opacity(0.40)
                        : Color.brandWarm.opacity(0.15)
                )
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isViewingToday)
    }
}
