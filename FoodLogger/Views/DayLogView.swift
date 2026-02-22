import SwiftUI
import SwiftData

// MARK: - Shell

struct DayLogView: View {
    @Query private var allEntries: [FoodEntry]
    @State private var highlightedEntryID: UUID?

    // Page-based date navigation
    private static let referenceDate: Date = Calendar.current.startOfDay(for: Date())
    private static let todayIndex: Int = 365          // index within the 366-page range
    private static let totalDays: Int = 366           // 365 days back + today
    @State private var selectedIndex: Int = DayLogView.todayIndex

    // Sheets
    @State private var showSearch = false

    private let streakService = StreakService()

    private var streakInfo: StreakService.StreakInfo {
        streakService.compute(from: allEntries)
    }

    private var displayedDate: Date { date(at: selectedIndex) }

    private var isToday: Bool { selectedIndex == DayLogView.todayIndex }

    private func date(at index: Int) -> Date {
        let offset = index - DayLogView.todayIndex
        return Calendar.current.date(byAdding: .day, value: offset, to: DayLogView.referenceDate)
            ?? DayLogView.referenceDate
    }

    private func index(for date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: DayLogView.referenceDate, to: date).day ?? 0
        return max(0, min(DayLogView.todayIndex + days, DayLogView.totalDays - 1))
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(0..<DayLogView.totalDays, id: \.self) { index in
                let pageDate = date(at: index)
                DayLogBody(
                    date: pageDate,
                    isToday: index == DayLogView.todayIndex,
                    highlightedEntryID: $highlightedEntryID
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(formattedTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSearch) {
            SearchView { date, entryID in
                withAnimation(.none) {
                    selectedIndex = index(for: Calendar.current.startOfDay(for: date))
                }
                highlightedEntryID = entryID
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickAction)) { notification in
            guard let action = notification.object as? String else { return }
            switch action {
            case "addEntry":
                withAnimation(.none) { selectedIndex = DayLogView.todayIndex }
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    NotificationCenter.default.post(name: .openAddEntry, object: nil)
                }
            case "viewToday":
                withAnimation(.none) { selectedIndex = DayLogView.todayIndex }
            default:
                break
            }
        }
    }

    private var formattedTitle: String {
        isToday ? "Today" : displayedDate.formatted(.dateTime.weekday(.abbreviated).month(.wide).day())
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            streakBadge
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
            }

            if isToday {
                todayPill
            } else {
                Button("Today") {
                    withAnimation(.none) { selectedIndex = DayLogView.todayIndex }
                }
                .tint(.accentColor)
            }
        }
    }

    @ViewBuilder
    private var streakBadge: some View {
        if streakInfo.count > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(streakInfo.count)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }

    private var todayPill: some View {
        Text("Today")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor, in: Capsule())
    }
}

// MARK: - Body

private struct DayLogBody: View {
    let date: Date
    let isToday: Bool
    @Binding var highlightedEntryID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FoodEntry]

    @State private var showAddSheet = false
    @State private var entryToEdit: FoodEntry?
    @State private var toastMessage: String?

    init(date: Date, isToday: Bool, highlightedEntryID: Binding<UUID?>) {
        self.date = date
        self.isToday = isToday
        _highlightedEntryID = highlightedEntryID
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _entries = Query(
            filter: #Predicate<FoodEntry> { entry in
                entry.date >= start && entry.date < end
            },
            sort: \.createdAt
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if entries.isEmpty {
                emptyStateView
            } else {
                entryList
            }
            fabButton
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
        .sheet(isPresented: $showAddSheet) {
            AddEntryView(forDate: date)
        }
        .sheet(item: $entryToEdit) { entry in
            AddEntryView(forDate: date, editingEntry: entry)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddEntry)) { _ in
            if isToday { showAddSheet = true }
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(entries) { entry in
                    EntryCardView(
                        entry: entry,
                        isToday: isToday,
                        isHighlighted: highlightedEntryID == entry.id
                    )
                    .id(entry.id)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            entryToEdit = entry
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            entryToEdit = entry
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            duplicate(entry)
                        } label: {
                            Label(isToday ? "I ate again" : "I ate it today", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
            .task(id: highlightedEntryID) {
                guard let id = highlightedEntryID else { return }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
                try? await Task.sleep(for: .seconds(2))
                highlightedEntryID = nil
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text(isToday ? "Nothing logged yet" : "No entries for this day")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Tap + to add an entry")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - FAB

    private var fabButton: some View {
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

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toastMessage {
            Text(message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func delete(_ entry: FoodEntry) {
        if let mediaURL = entry.mediaURL {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsDir.appendingPathComponent(mediaURL.absoluteString)
            try? FileManager.default.removeItem(at: fileURL)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        modelContext.delete(entry)
    }

    private func duplicate(_ entry: FoodEntry) {
        let today = Calendar.current.startOfDay(for: Date())
        let copy = FoodEntry(
            date: today,
            rawInput: entry.rawInput,
            inputType: entry.inputType,
            processedDescription: entry.processedDescription,
            category: entry.category
        )
        modelContext.insert(copy)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToast("Entry duplicated to today")
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.3)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }
}
