import SwiftUI
import SwiftData

struct CalendarHomeView: View {
    @Query private var allEntries: [FoodEntry]
    @State private var displayedMonth: Date = Self.currentMonthStart()

    private static func currentMonthStart() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components)!
    }

    private var datesWithEntries: Set<Date> {
        Set(allEntries.map { Calendar.current.startOfDay(for: $0.date) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader

                dayOfWeekHeader
                    .padding(.bottom, 4)

                calendarGrid
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: displayedMonth)

                Divider()
                    .padding(.top, 8)

                Spacer()
            }
            .navigationTitle("Food Log")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Date.self) { date in
                DayLogView(date: date)
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                advanceMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                advanceMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        let calendar = Calendar.current
        let weekdays = calendar.shortWeekdaySymbols

        return HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let dates = calendarDates(for: displayedMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<42, id: \.self) { index in
                if let date = dates[index] {
                    NavigationLink(value: date) {
                        DayCell(
                            date: date,
                            isToday: Calendar.current.isDateInToday(date),
                            hasEntries: datesWithEntries.contains(Calendar.current.startOfDay(for: date))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    // MARK: - Calendar Math

    private func calendarDates(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        let firstDay = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: offset)
        for day in 0..<daysInMonth {
            let date = calendar.date(byAdding: .day, value: day, to: firstDay)
            dates.append(date)
        }
        while dates.count < 42 {
            dates.append(nil)
        }
        return dates
    }

    private func advanceMonth(by value: Int) {
        let calendar = Calendar.current
        if let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = next
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isToday: Bool
    let hasEntries: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(dayNumber)")
                .font(.system(size: 16, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                )

            Circle()
                .fill(hasEntries ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
