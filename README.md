# FoodLogger

A native iOS food diary app with a **Dark Editorial Journal** aesthetic. Log what you ate — by typing, speaking, or photographing your meal. Everything is stored as plain text tied to a calendar date. No calories, no macros, no accounts.

## Features

| Mode | How it works |
|------|-------------|
| **Text** | Type a free-form description of your meal |
| **Voice** *(Beta)* | Record yourself speaking; transcribed on-device via `SFSpeechRecognizer` |
| **Photo** *(Beta)* | Pick from library or take a photo; classified on-device via `VNClassifyImageRequest` |

- AI-generated description shown before saving — edit it before committing
- Auto-detected meal categories (Breakfast, Lunch, Snack, Dinner, Dessert, Beverage) with manual override
- Bottom tab bar navigation: Journal, Calendar, Foods, Insights, Settings
- Day log home screen (Journal tab) — swipe left/right to move between days; editorial banner shows the viewed day's date and contextual label (good morning / yesterday / X days ago)
- Swipe left on an entry to delete or edit; full swipe deletes instantly
- Long-press for context menu: edit, "I ate it today" / "I ate again", delete
- Full-screen calendar tab to browse and navigate to any past day
- Full-text search across all entries
- Weekly and monthly summary view
- Consecutive-day streak counter
- Foods tab: searchable list of every food you've logged, ranked by frequency — tap any item to see its full history (occurrence timeline, day-of-week pattern, time-of-day distribution, mood breakdown)
- Analytics dashboard (Insights tab): weekly story headline, top foods, daily activity, category breakdown, mood distribution, meal timing, week-over-week comparison, monthly heatmap, stats card, personal records card (longest streak / best day / unique foods)
- Mood/Energy tagging: log how a meal made you feel (⚡️ Energised, 😌 Satisfied, 😐 Neutral, 😴 Sluggish, 😣 Uncomfortable); mood emoji shown on each card
- Favourites quick-log: your top 5 most-eaten foods appear as tappable pills when adding a new entry
- Calendar tab shows entry-density heatmap — deeper orange for more entries on a day
- Entry save celebration: spring haptic + contextual toast ("First entry today!" / "Meal #N today!") on the Today tab
- Streak flame color-shifts amber → orange → red as the streak grows
- Milestone confetti at 10 / 25 / 50 / 100 / 250 total entries (one-time, stored in UserDefaults)
- "Streak at risk" notification at 8 pm when you have a streak but haven't logged yet
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
│   ├── FoodEntry.swift              # @Model — id, date, rawInput, inputType, processedDescription, mediaURL, category, mood, updatedAt
│   ├── MealCategory.swift           # enum — breakfast, lunch, snack, dinner, dessert, beverage
│   └── MoodTag.swift                # enum — energised, satisfied, neutral, sluggish, uncomfortable; has .emoji, .label, .color
├── Views/
│   ├── AppShellView.swift           # 5-tab outer TabView; weekly recap deep-link listener
│   ├── TodayTabView.swift           # Editorial banner (viewed day's date + contextual label) + DayLogView
│   ├── CalendarTabView.swift        # Full-screen split calendar + inline day entries
│   ├── FoodsTabView.swift           # Searchable food list ranked by frequency; pushes FoodItemTimelineView
│   ├── DayLogView.swift             # Home screen (shell + body pattern), streak badge
│   ├── AddEntryView.swift           # Text / Voice (β) / Photo (β) input + edit mode; beta banners
│   ├── EntryCardView.swift          # Card with full-width colored category header band + dark body, category badge menu, "edited" label
│   ├── CalendarView.swift           # Month-grid sheet for date navigation
│   ├── SearchView.swift             # Full-text search across all entries
│   ├── SummaryView.swift            # Weekly / monthly grouped entry list
│   ├── FoodItemTimelineView.swift   # Push destination: occurrence timeline, day-of-week pattern, time-of-day distribution, mood chart for a specific food
│   ├── InsightsView.swift           # Analytics dashboard — story headline, stats, records, 8 Swift Charts cards + period picker
│   ├── WeeklyRecapView.swift        # 6-page animated weekly recap; ConfettiView/ConfettiParticle now internal for reuse
│   ├── StyleGuide.swift             # Brand palette (brandVoid/brandPrimary/brandAccent/brandWarm/brandSurface/brandSuccess), rounded + serif Font extensions, CardModifier, EmptyStateView
│   ├── AppIconView.swift            # 1024×1024 SwiftUI icon canvas ("YOUR FOOD." / "YOUR STORY." typographic wordmark); export PNG via Settings → Developer → Export App Icon
│   ├── LaunchScreenView.swift       # Animated launch screen — same typographic wordmark slides up on near-black navy; 1.4 s then calls onComplete
│   ├── OnboardingView.swift         # 4-page first-launch onboarding; page 1 shows typographic logo
│   └── SettingsView.swift           # Notifications, JSON export, Developer tools (DEBUG: export app icon + data seeding)
└── Services/
    ├── SpeechService.swift          # On-device speech recognition & live transcript
    ├── VisionService.swift          # On-device image classification
    ├── FoodDescriptionBuilder.swift # NLTagger noun extraction + Vision label cleaning
    ├── CategoryDetectionService.swift # Content-first meal category auto-detection
    ├── StreakService.swift           # Consecutive-day streak computation
    ├── NotificationService.swift    # Daily reminders + Sunday weekly recap + 8pm streak-at-risk notification
    ├── ExportService.swift          # JSON serialisation + filename generation
    ├── InsightsService.swift        # Typed analytics over [FoodEntry] — topItems, dailyCounts, categoryDistribution, inputTypeBreakdown, mealTiming, weekOverWeekTrend, monthlyHeatmap, coOccurrence, moodDistribution + food-item timeline methods
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

## App Icon

`AppIconView.swift` is the source-of-truth design canvas (1024×1024 SwiftUI). The asset catalog slot exists but needs a PNG placed in it. **Workflow to update the icon:**

1. Run the app in a **Debug** build on simulator or device
2. Go to **Settings → Developer → Export App Icon**
3. Share/save the `AppIcon-1024.png` to your Mac (via AirDrop, Files, etc.)
4. In Xcode, open `FoodLogger/Assets.xcassets/AppIcon.appiconset`
5. Drag the PNG into the **light** slot (and optionally dark/tinted slots)
6. Rebuild and reinstall

## UserDefaults keys

| Key | Type | Purpose |
|-----|------|---------|
| `"onboardingComplete"` | `Bool` | Set after first-launch onboarding is dismissed |
| `"triggeredMilestones"` | `[Int]` | Milestone entry counts (10/25/50/100/250) already celebrated; prevents repeat confetti |
| `"widget_streak"` | `Int` | Current streak written by app for Home Screen Widget |
| `"widget_today_count"` | `Int` | Today's entry count written by app for Home Screen Widget |
| `"widget_last_entry"` | `String` | Most recent entry today written by app for Home Screen Widget |

## Home Screen Widget

Widget source lives in `Widget/FoodLoggerWidget.swift` — **not compiled into the main app target**. The app already writes all required data to a shared App Group UserDefaults (`group.com.ashwath.ios.FoodLogger`) on every entry change. To activate the widget, follow the 5-minute setup in `Widget/SETUP.md`.
