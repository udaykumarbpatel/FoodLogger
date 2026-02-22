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
        case 5..<12:  return "Good morning 👋"
        case 12..<17: return "Good afternoon 👋"
        default:      return "Good evening 👋"
        }
    }

    private var friendlyDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.appTitle)
                    .foregroundStyle(.white)
                Text(friendlyDate)
                    .font(.appSubheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if streakInfo.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streakInfo.count)")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                }
                Text("\(todayEntryCount) \(todayEntryCount == 1 ? "entry" : "entries") today")
                    .font(.appCaption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
