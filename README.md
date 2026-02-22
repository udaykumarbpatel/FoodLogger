# FoodLogger

A native iOS food diary app. Log what you ate — by typing, speaking, or photographing your meal. Everything is stored as plain text tied to a calendar date. No calories, no macros, no accounts.

## Features

| Mode | How it works |
|------|-------------|
| **Text** | Type a free-form description of your meal |
| **Voice** | Record yourself speaking; transcribed on-device via `SFSpeechRecognizer` |
| **Photo** | Pick from library or take a photo; classified on-device via `VNClassifyImageRequest` |

- AI-generated description shown before saving — edit it before committing
- Auto-detected meal categories (Breakfast, Lunch, Snack, Dinner, Dessert, Beverage) with manual override
- Day log home screen — swipe left/right to move between days
- Swipe left on an entry to delete or edit; full swipe deletes instantly
- Long-press for context menu: edit, "I ate it today" / "I ate again", delete
- Calendar sheet to browse and navigate to any past day
- Full-text search across all entries
- Weekly and monthly summary view
- Consecutive-day streak counter
- Daily reminder notifications (skips days you've already logged)
- Home screen quick actions: "Log Food Now" and "View Today"
- Expand an entry card to see the original input or image thumbnail
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
| Camera / Photos | `AVFoundation` + `PhotosUI` |
| Notifications | `UserNotifications` framework |

## Project Structure

```
FoodLogger/
├── App/
│   └── FoodLoggerApp.swift          # @main, SwiftData ModelContainer, AppDelegate, quick actions
├── Models/
│   ├── FoodEntry.swift              # @Model — id, date, rawInput, inputType, processedDescription, mediaURL, category, updatedAt
│   └── MealCategory.swift           # enum — breakfast, lunch, snack, dinner, dessert, beverage
├── Views/
│   ├── DayLogView.swift             # Home screen (shell + body pattern), streak badge, toolbar navigation
│   ├── AddEntryView.swift           # Text / Voice / Photo input + edit mode
│   ├── EntryCardView.swift          # Expandable journal-style card with category badge
│   ├── CalendarView.swift           # Month-grid sheet for date navigation
│   ├── SearchView.swift             # Full-text search across all entries
│   ├── SummaryView.swift            # Weekly / monthly grouped entry list
│   ├── SettingsView.swift           # Daily reminder toggle + time picker
│   └── CalendarHomeView.swift       # Legacy standalone calendar (retained for reference)
└── Services/
    ├── SpeechService.swift          # On-device speech recognition & live transcript
    ├── VisionService.swift          # On-device image classification
    ├── FoodDescriptionBuilder.swift # NLTagger noun extraction + Vision label cleaning
    ├── CategoryDetectionService.swift # Content-first meal category auto-detection
    ├── StreakService.swift           # Consecutive-day streak computation
    └── NotificationService.swift    # Daily reminder scheduling via UNUserNotificationCenter
FoodLoggerTests/
    ├── FoodDescriptionBuilderTests.swift  (12 tests)
    ├── FoodEntryModelTests.swift          (9 tests)
    ├── VisionServiceTests.swift           (4 tests)
    └── MealCategoryTests.swift            (13 tests)
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
| Notifications | Daily meal-logging reminders |

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

37 tests across 4 suites covering the data model, description builder, Vision service, and meal category detection.
