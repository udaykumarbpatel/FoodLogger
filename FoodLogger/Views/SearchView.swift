import SwiftUI
import SwiftData

struct SearchView: View {
    let onSelectEntry: (Date, UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [(date: Date, entries: [FoodEntry])] = []

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Your Journal",
                        systemImage: "magnifyingglass",
                        description: Text("Type to search your food entries")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search entries…")
            .onChange(of: searchText) { _, newText in
                performSearch(query: newText)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var resultsList: some View {
        List {
            ForEach(results, id: \.date) { group in
                Section {
                    ForEach(group.entries) { entry in
                        SearchResultRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectEntry(entry.date, entry.id)
                                dismiss()
                            }
                    }
                } header: {
                    Text(group.date.formatted(.dateTime.weekday(.abbreviated).month(.wide).day()))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        let descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let filtered = all.filter {
            $0.processedDescription.localizedCaseInsensitiveContains(trimmed)
                || $0.rawInput.localizedCaseInsensitiveContains(trimmed)
        }
        let grouped = Dictionary(grouping: filtered) {
            Calendar.current.startOfDay(for: $0.date)
        }
        results = grouped.sorted { $0.key > $1.key }.map { (date: $0.key, entries: $0.value) }
    }
}

// MARK: - Result Row

private struct SearchResultRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.processedDescription)
                .font(.body)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let cat = entry.category {
                    Label(cat.displayName, systemImage: cat.icon)
                        .font(.caption)
                        .foregroundStyle(cat.color)
                }
                Text(entry.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
