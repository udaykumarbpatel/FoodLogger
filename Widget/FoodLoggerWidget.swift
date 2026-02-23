//
//  FoodLoggerWidget.swift
//  FoodLoggerWidget
//
//  Home Screen widget showing today's log count and current streak.
//  WIDGET EXTENSION TARGET — not compiled in main app target.
//  See SETUP.md for instructions on adding the extension target in Xcode.
//

import WidgetKit
import SwiftUI

// MARK: - Shared data keys (must match AppShellView writes)

private let appGroup = "group.com.ashwath.ios.FoodLogger"
private let keyStreak      = "widget_streak"
private let keyTodayCount  = "widget_today_count"
private let keyLastEntry   = "widget_last_entry"

// MARK: - Timeline Entry

struct FoodWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayCount: Int
    let lastEntry: String
}

// MARK: - Provider

struct FoodWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodWidgetEntry {
        FoodWidgetEntry(date: Date(), streak: 7, todayCount: 3, lastEntry: "Oatmeal")
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh at the next midnight so today's count resets
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func currentEntry() -> FoodWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroup) ?? .standard
        let streak     = defaults.integer(forKey: keyStreak)
        let todayCount = defaults.integer(forKey: keyTodayCount)
        let lastEntry  = defaults.string(forKey: keyLastEntry) ?? ""
        return FoodWidgetEntry(date: Date(), streak: streak, todayCount: todayCount, lastEntry: lastEntry)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: FoodWidgetEntry

    var body: some View {
        ZStack {
            Color(red: 0.028, green: 0.043, blue: 0.094) // brandVoid
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(entry.streak > 0 ? "\u{1F525}" : "\u{1F4D3}")
                        .font(.system(size: 20))
                    Text("\(entry.streak)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.21)) // brandAccent
                }
                Text("day streak")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.todayCount)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.969, green: 0.953, blue: 0.933)) // brandSurface
                Text("logged today")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: FoodWidgetEntry

    var body: some View {
        ZStack {
            Color(red: 0.028, green: 0.043, blue: 0.094)
            HStack(spacing: 0) {
                // Left column — streak + today count
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(entry.streak > 0 ? "\u{1F525}" : "\u{1F4D3}")
                            .font(.system(size: 18))
                        Text("\(entry.streak) day streak")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.21))
                    }
                    Text("\(entry.todayCount) logged today")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.969, green: 0.953, blue: 0.933))
                    Spacer()
                    if !entry.lastEntry.isEmpty {
                        Text("Last: \(entry.lastEntry)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Right column — tap to log CTA
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.21))
                    Text("Log Food")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.969, green: 0.953, blue: 0.933))
                }
                .frame(width: 90)
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Widget Configuration

struct FoodLoggerWidget: Widget {
    let kind = "FoodLoggerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FoodWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
                .widgetURL(URL(string: "foodlogger://addEntry")!)
                .containerBackground(Color(red: 0.028, green: 0.043, blue: 0.094), for: .widget)
        }
        .configurationDisplayName("Food Logger")
        .description("Track your streak and today's entries.")
        .supportedFamilies([.systemSmall])
    }
}

struct FoodLoggerWidgetMedium: Widget {
    let kind = "FoodLoggerWidgetMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FoodWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .widgetURL(URL(string: "foodlogger://addEntry")!)
                .containerBackground(Color(red: 0.028, green: 0.043, blue: 0.094), for: .widget)
        }
        .configurationDisplayName("Food Logger")
        .description("Streak, today's count, and quick-log shortcut.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct FoodLoggerWidgetBundle: WidgetBundle {
    var body: some Widget {
        FoodLoggerWidget()
        FoodLoggerWidgetMedium()
    }
}
