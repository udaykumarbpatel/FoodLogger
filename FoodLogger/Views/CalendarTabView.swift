import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Query private var allEntries: [FoodEntry]
    @State private var displayedMonth: Date = {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: comps) ?? Date()
    }()
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current

    /// Entry count per calendar day — used for heatmap intensity.
    private var entriesPerDay: [Date: Int] {
        var counts: [Date: Int] = [:]
        for entry in allEntries {
            let day = calendar.startOfDay(for: entry.date)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private var monthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        return calendar.date(from: comps) ?? displayedMonth
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

    private var selectedDayEntries: [FoodEntry] {
        guard let date = selectedDate else { return [] }
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return allEntries.filter { $0.date >= start && $0.date < end }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month grid
                VStack(spacing: 12) {
                    monthNavHeader
                    dayOfWeekRow
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 7),
                        spacing: 10
                    ) {
                        ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                            if let date {
                                CalendarTabDayCell(
                                    date: date,
                                    isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                                    isToday: calendar.isDateInToday(date),
                                    entryCount: entriesPerDay[calendar.startOfDay(for: date)] ?? 0
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = date
                                    }
                                }
                            } else {
                                Color.clear.frame(height: 52)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
                .background(Color.brandVoid)

                Rectangle()
                    .fill(Color.brandAccent.opacity(0.25))
                    .frame(height: 1)

                // Day entries panel
                if let date = selectedDate {
                    dayEntriesPanel(for: date)
                } else {
                    noSelectionPrompt
                }
            }
            .background(Color.brandVoid)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.brandVoid, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Today") {
                        let comps = calendar.dateComponents([.year, .month], from: Date())
                        displayedMonth = calendar.date(from: comps) ?? Date()
                        selectedDate = calendar.startOfDay(for: Date())
                    }
                }
            }
        }
    }

    // MARK: - Month Nav Header

    private var monthNavHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            // Month name in editorial serif
            VStack(alignment: .leading, spacing: 0) {
                Text(monthStart.formatted(.dateTime.month(.wide)))
                    .font(.appDisplaySerif)
                    .foregroundStyle(Color.brandSurface)
                Text(monthStart.formatted(.dateTime.year()))
                    .font(.appCaption)
                    .foregroundStyle(Color.brandWarm.opacity(0.8))
                    .kerning(0.5)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                        withAnimation(.easeInOut(duration: 0.2)) { displayedMonth = prev }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandSurface.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.brandSurface.opacity(0.07))
                        .clipShape(Circle())
                }

                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                        withAnimation(.easeInOut(duration: 0.2)) { displayedMonth = next }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandSurface.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.brandSurface.opacity(0.07))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Day of Week Row

    private var dayOfWeekRow: some View {
        HStack {
            ForEach(0..<7, id: \.self) { i in
                let index = (calendar.firstWeekday - 1 + i) % 7
                Text(calendar.veryShortWeekdaySymbols[index])
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .kerning(0.5)
                    .foregroundStyle(Color.brandWarm.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Day Entries Panel

    @ViewBuilder
    private func dayEntriesPanel(for date: Date) -> some View {
        let entries = selectedDayEntries
        let isToday = calendar.isDateInToday(date)
        let title = isToday ? "Today" : date.formatted(.dateTime.weekday(.wide).month(.wide).day())

        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.appHeadlineSerif)
                .foregroundStyle(Color.brandSurface)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)

            if entries.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Text("Nothing logged.")
                        .font(.appTitleSerif)
                        .foregroundStyle(Color.brandSurface.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            } else {
                List {
                    ForEach(entries) { entry in
                        EntryCardView(entry: entry, isToday: isToday)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.brandVoid)
            }
        }
    }

    // MARK: - No Selection Prompt

    private var noSelectionPrompt: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("Select a day.")
                .font(.appTitleSerif)
                .foregroundStyle(Color.brandSurface.opacity(0.35))
            Text("Tap any date above to see its entries.")
                .font(.appCaption)
                .foregroundStyle(Color.brandWarm.opacity(0.4))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Cell

private struct CalendarTabDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let entryCount: Int

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Heatmap fill
            Circle().fill(cellBackground)

            // Today: cream ring outline
            if isToday && !isSelected {
                Circle()
                    .strokeBorder(Color.brandSurface.opacity(0.7), lineWidth: 1.5)
            }

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular, design: .rounded))
                .foregroundStyle(dayTextColor)
        }
        .frame(width: 38, height: 38)
        .frame(height: 52)
    }

    private var cellBackground: Color {
        if isSelected { return Color.brandAccent }
        switch entryCount {
        case 0:    return Color.clear
        case 1:    return Color.brandAccent.opacity(0.22)
        case 2:    return Color.brandAccent.opacity(0.50)
        default:   return Color.brandAccent.opacity(0.80)
        }
    }

    private var dayTextColor: Color {
        if isSelected { return .white }
        if isToday { return Color.brandSurface }
        if entryCount >= 2 { return .white }
        if entryCount == 1 { return Color.brandSurface.opacity(0.9) }
        return Color.brandSurface.opacity(0.45)
    }
}
