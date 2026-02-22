import SwiftUI
import SwiftData

struct SummaryView: View {
    let onSelectDate: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\FoodEntry.date, order: .reverse)]) private var allEntries: [FoodEntry]

    enum SummaryMode: String, CaseIterable {
        case weekly = "Week"
        case monthly = "Month"
    }

    @State private var mode: SummaryMode = .weekly

    private var filteredEntries: [FoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        let interval: DateInterval
        if mode == .weekly {
            interval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        } else {
            interval = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        }
        return allEntries.filter { interval.contains($0.date) }
    }

    private var groupedEntries: [(date: Date, entries: [FoodEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, entries: $0.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Period", selection: $mode) {
                    ForEach(SummaryMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if groupedEntries.isEmpty {
                    ContentUnavailableView(
                        "No entries this \(mode == .weekly ? "week" : "month")",
                        systemImage: "fork.knife",
                        description: Text("Start logging to see your summary")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedEntries, id: \.date) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    SummaryEntryRow(entry: entry)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSelectDate(entry.date)
                                            dismiss()
                                        }
                                }
                            } header: {
                                Text(group.date.formatted(.dateTime.weekday(.abbreviated).month(.wide).day()))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Entry Row

private struct SummaryEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            if let cat = entry.category {
                Image(systemName: cat.icon)
                    .foregroundStyle(cat.color)
                    .frame(width: 24)
            } else {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.tertiary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.processedDescription)
                    .font(.body)
                    .lineLimit(2)
                Text(entry.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
