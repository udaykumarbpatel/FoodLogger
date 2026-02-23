import SwiftUI
import SwiftData

struct TodayTabView: View {
    @Query private var allEntries: [FoodEntry]

    private let streakService = StreakService()

    private var streakInfo: StreakService.StreakInfo {
        streakService.compute(from: allEntries)
    }

    private var todayEntryCount: Int {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return allEntries.filter { $0.date >= start && $0.date < end }.count
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var friendlyDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// Flame color shifts amber → orange → red as streak grows.
    private var flameColor: Color {
        switch streakInfo.count {
        case 0..<7:   return Color.brandWarm
        case 7..<14:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        NavigationStack {
            DayLogView()
                .safeAreaInset(edge: .top, spacing: 0) {
                    bannerView
                }
        }
    }

    private var bannerView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    // Greeting in small-caps amber
                    Text(greeting.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(Color.brandWarm.opacity(0.85))

                    // Date in editorial serif
                    Text(friendlyDate)
                        .font(.appTitleSerif)
                        .foregroundStyle(Color.brandSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    if streakInfo.count > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(flameColor)
                            Text("\(streakInfo.count)")
                                .fontWeight(.black)
                                .foregroundStyle(Color.brandSurface)
                        }
                        .font(.title3)
                    }
                    Text("\(todayEntryCount) \(todayEntryCount == 1 ? "entry" : "entries") today")
                        .font(.appCaption)
                        .foregroundStyle(Color.brandSurface.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.brandVoid)

            // Ruled journal line at the bottom
            Rectangle()
                .fill(Color.brandAccent.opacity(0.35))
                .frame(height: 1)
        }
    }
}
