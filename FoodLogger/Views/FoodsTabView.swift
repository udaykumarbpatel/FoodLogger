//
//  FoodsTabView.swift
//  FoodLogger
//
//  Tab 3 — searchable list of food items that drills into
//  FoodItemTimelineView for per-item occurrence analytics.
//

import SwiftUI
import SwiftData

struct FoodsTabView: View {

    @Query private var allEntries: [FoodEntry]

    @State private var searchText: String = ""

    private let service = InsightsService()

    // MARK: - Derived data

    /// All food tokens, ranked by frequency (all-time).
    private var allFoods: [FoodItemFrequency] {
        service.topItems(from: allEntries, period: .allTime, limit: 200)
    }

    private var filteredFoods: [FoodItemFrequency] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allFoods }
        return allFoods.filter { $0.item.lowercased().contains(query) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty {
                    emptyStateView
                } else {
                    foodList
                }
            }
            .background(Color.brandVoid)
            .navigationTitle("Foods")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.brandVoid, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods…")
        }
    }

    // MARK: - Food List

    private var foodList: some View {
        List {
            if filteredFoods.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.brandSurface.opacity(0.3))
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(Color.brandSurface.opacity(0.4))
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
                .listRowBackground(Color.brandVoid)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredFoods) { food in
                    NavigationLink(destination: FoodItemTimelineView(term: food.item, entries: allEntries)) {
                        foodRow(food)
                    }
                    .listRowBackground(Color.brandVoid)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func foodRow(_ food: FoodItemFrequency) -> some View {
        HStack(spacing: 12) {
            Text(food.item.capitalized)
                .font(.appBody)
                .foregroundStyle(Color.brandSurface)

            Spacer()

            Text("\(food.count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.brandAccent, in: Capsule())
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 44))
                .foregroundStyle(Color.brandAccent.opacity(0.5))
            Text("No foods logged yet.")
                .font(.appTitleSerif)
                .foregroundStyle(Color.brandSurface.opacity(0.6))
            Text("Start logging meals to explore your food patterns.")
                .font(.appSubheadline)
                .foregroundStyle(Color.brandWarm.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
