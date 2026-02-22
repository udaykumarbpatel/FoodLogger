import SwiftUI
import SwiftData

struct DayLogView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FoodEntry]
    @State private var showAddSheet: Bool = false

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _entries = Query(
            filter: #Predicate<FoodEntry> { entry in
                entry.date >= start && entry.date < end
            },
            sort: \FoodEntry.createdAt
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if entries.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(entries) { entry in
                                EntryCardView(entry: entry)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(entry)
                                        } label: {
                                            Label("Delete Entry", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .padding(.bottom, 80)
                    }
                }
            }

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .padding(20)
        }
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            AddEntryView()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No entries yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Tap + to log what you ate")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 80)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
    }

    private func delete(_ entry: FoodEntry) {
        if let mediaURL = entry.mediaURL {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsDir.appendingPathComponent(mediaURL.absoluteString)
            try? FileManager.default.removeItem(at: fileURL)
        }
        modelContext.delete(entry)
    }
}
