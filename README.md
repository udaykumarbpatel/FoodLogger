# FoodLogger

A native iOS food diary app. Log what you ate — by typing, speaking, or photographing your meal. Everything is stored as plain text tied to a calendar date. No calories, no macros, no accounts.

## Features

| Mode | How it works |
|------|-------------|
| **Text** | Type a free-form description of your meal |
| **Voice** *(Beta)* | Record yourself speaking; transcribed on-device via `SFSpeechRecognizer` |
| **Photo** *(Beta)* | Pick from library or take a photo; classified on-device via `VNClassifyImageRequest` |

- AI-generated description shown before saving — edit it before committing
- Auto-detected meal categories (Breakfast, Lunch, Snack, Dinner, Dessert, Beverage) with manual override
- Bottom tab bar navigation: Today, Calendar, Insights, Settings
- Day log home screen — swipe left/right to move between days
- Swipe left on an entry to delete or edit; full swipe deletes instantly
- Long-press for context menu: edit, "I ate it today" / "I ate again", delete
- Full-screen calendar tab to browse and navigate to any past day
- Full-text search across all entries
- Weekly and monthly summary view
- Consecutive-day streak counter
- Analytics dashboard (Insights tab): top foods, daily activity, category breakdown, meal timing, week-over-week comparison, monthly heatmap, food search, stats card
- Weekly Recap: 6-page animated recap shown every Monday on launch and via Sunday 7 pm push notification
- Daily reminder notifications (skips days you've already logged)
- Export all entries as a JSON file (share or save via the standard iOS share sheet)
- Home screen quick actions: "Log Food Now" and "View Today"
- Full Dark Mode support
- 100% offline — zero network requests

## Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Speech | `Speech` framework — `SFSpeechRecognizer` with `requiresOnDeviceRecognition` |
| Vision | `Vision` framework — `VNClassifyImageRequest` |
| NLP | `NaturalLanguage` framework — `NLTagger` noun/adjective extraction |
| Charts | `Charts` framework — Swift Charts |
| Camera / Photos | `AVFoundation` + `PhotosUI` |
| Notifications | `UserNotifications` framework |

## Project Structure

```
FoodLogger/
├── App/
│   └── FoodLoggerApp.swift          # @main, SwiftData ModelContainer, AppDelegate, quick actions, Monday recap trigger
├── Models/
│   ├── FoodEntry.swift              # @Model — id, date, rawInput, inputType, processedDescription, mediaURL, category, updatedAt
│   └── MealCategory.swift           # enum — breakfast, lunch, snack, dinner, dessert, beverage
├── Views/
│   ├── AppShellView.swift           # 4-tab outer TabView; weekly recap deep-link listener
│   ├── TodayTabView.swift           # Gradient banner + DayLogView
│   ├── CalendarTabView.swift        # Full-screen split calendar + inline day entries
│   ├── DayLogView.swift             # Home screen (shell + body pattern), streak badge, search toolbar
│   ├── AddEntryView.swift           # Text / Voice (β) / Photo (β) input + edit mode; beta banners
│   ├── EntryCardView.swift          # Card with colored left bar, category badge menu, "edited" label
│   ├── CalendarView.swift           # Month-grid sheet for date navigation
│   ├── SearchView.swift             # Full-text search across all entries
│   ├── SummaryView.swift            # Weekly / monthly grouped entry list
│   ├── InsightsView.swift           # Analytics dashboard — 8 Swift Charts cards + period picker
│   ├── WeeklyRecapView.swift        # 6-page animated weekly recap (Hero, Stats, Top Food, Categories, Consistency, Share)
│   ├── StyleGuide.swift             # Font extensions, CardModifier, EmptyStateView
│   └── SettingsView.swift           # Notifications, JSON export, Developer tools (DEBUG)
└── Services/
    ├── SpeechService.swift          # On-device speech recognition & live transcript
    ├── VisionService.swift          # On-device image classification
    ├── FoodDescriptionBuilder.swift # NLTagger noun extraction + Vision label cleaning
    ├── CategoryDetectionService.swift # Content-first meal category auto-detection
    ├── StreakService.swift           # Consecutive-day streak computation
    ├── NotificationService.swift    # Daily reminders + Sunday weekly recap notification
    ├── ExportService.swift          # JSON serialisation + filename generation
    ├── InsightsService.swift        # Typed analytics over [FoodEntry] — 8 methods, 5 periods
    ├── WeeklySummaryService.swift   # WeeklySummary computation + headline/subheadline generation
    └── SampleDataService.swift      # 120-day deterministic sample data seeding
FoodLoggerTests/
    ├── FoodDescriptionBuilderTests.swift  (12 tests)
    ├── FoodEntryModelTests.swift          (9 tests)
    ├── VisionServiceTests.swift           (4 tests)
    ├── MealCategoryTests.swift            (47 tests)
    ├── ExportServiceTests.swift           (20 tests)
    ├── InsightsServiceTests.swift         (37 tests)
    ├── SampleDataServiceTests.swift       (10 tests)
    ├── WeeklySummaryServiceTests.swift    (25 tests)
    └── NotificationRecapTests.swift       (15 tests)
```

## Requirements

- Xcode 26.2+
- iOS 26.2 SDK (deployment target)
- No external dependencies — pure Apple frameworks only

## Permissions

The app requests the following permissions on first use:

| Permission | Purpose |
|-----------|---------|
| Microphone | Record voice meal descriptions |
| Speech Recognition | Transcribe recordings on-device |
| Camera | Photograph meals |
| Photo Library | Log meals from existing photos |
| Notifications | Daily meal-logging reminders + weekly recap |

## Running

1. Open `FoodLogger.xcodeproj` in Xcode
2. Select a simulator or device (iPhone or iPad)
3. Press **⌘R**

No additional setup required — there are no external dependencies, API keys, or configuration files.

## Testing

```bash
xcodebuild test \
  -scheme FoodLogger \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

179 tests across 9 suites covering the data model, description builder, Vision service, meal category detection, JSON export, analytics, sample data seeding, weekly summary, and notification scheduling.
