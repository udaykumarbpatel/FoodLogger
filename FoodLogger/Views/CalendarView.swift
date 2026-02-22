import SwiftUI
import SwiftData

struct CalendarView: View {
    let selectedDate: Date
    let onSelectDate: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var allEntries: [FoodEntry]
    @State private var displayedMonth: Date

    private let calendar = Calendar.current

    init(selectedDate: Date, onSelectDate: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.onSelectDate = onSelectDate
        let monthComponents = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        _displayedMonth = State(initialValue: Calendar.current.date(from: monthComponents) ?? selectedDate)
    }

    private var daysWithEntries: Set<Date> {
        Set(allEntries.map { calendar.startOfDay(for: $0.date) })
    }

    private var monthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return calendar.date(from: components) ?? displayedMonth
    }

    private var monthDays: [Date?] {
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let paddingBefore = (firstWeekday - calendar.firstWeekday + 7) % 7

        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        var days: [Date?] = Array(repeating: nil, count: paddingBefore)
        for day in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: day, to: monthStart) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthNavHeader
                dayOfWeekRow
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 7),
                    spacing: 8
                ) {
                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            CalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                hasEntries: daysWithEntries.contains(date)
                            )
                            .onTapGesture {
                                onSelectDate(date)
                                dismiss()
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Today") {
                        let components = calendar.dateComponents([.year, .month], from: Date())
                        displayedMonth = calendar.date(from: components) ?? Date()
                    }
                }
            }
        }
    }

    private var monthNavHeader: some View {
        HStack {
            Button {
                if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                    displayedMonth = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.headline)

            Spacer()

            Button {
                if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                    displayedMonth = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var dayOfWeekRow: some View {
        HStack {
            ForEach(0..<7, id: \.self) { i in
                let index = (calendar.firstWeekday - 1 + i) % 7
                Text(calendar.veryShortWeekdaySymbols[index])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEntries: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(dayTextColor)
                .frame(width: 36, height: 36)
                .background(dayBackground)
                .clipShape(Circle())

            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
                .opacity(hasEntries ? 1 : 0)
        }
        .frame(height: 48)
    }

    @ViewBuilder
    private var dayBackground: some View {
        if isToday {
            Circle().fill(Color.accentColor)
        } else if isSelected {
            Circle().fill(Color.accentColor.opacity(0.15))
        } else {
            Color.clear
        }
    }

    private var dayTextColor: Color {
        if isToday { return .white }
        if isSelected { return .accentColor }
        return .primary
    }
}
