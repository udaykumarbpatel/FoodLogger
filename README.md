# FoodLogger

A native iOS food diary app. Log what you ate — by typing, speaking, or photographing your meal. Everything is stored as plain text tied to a calendar date. No calories, no macros, no accounts.

## Features

| Mode | How it works |
|------|-------------|
| **Text** | Type a free-form description of your meal |
| **Voice** | Record yourself speaking; transcribed on-device via `SFSpeechRecognizer` |
| **Photo** | Pick from library or take a photo; classified on-device via `VNClassifyImageRequest` |

- Monthly calendar home screen with dot indicators on days that have entries
- Tap any day to see all entries in chronological order
- Expand an entry card to see the original input or image thumbnail
- Long-press an entry to delete it
- Haptic feedback on save
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

## Project Structure

```
FoodLogger/
├── App/
│   └── FoodLoggerApp.swift          # @main, SwiftData ModelContainer
├── Models/
│   └── FoodEntry.swift              # @Model — id, date, rawInput, inputType, processedDescription, mediaURL
├── Views/
│   ├── CalendarHomeView.swift       # Monthly grid, entry dot indicators
│   ├── DayLogView.swift             # Per-day entry list + FAB
│   ├── AddEntryView.swift           # Text / Voice / Photo input sheet
│   └── EntryCardView.swift          # Expandable journal-style card
└── Services/
    ├── SpeechService.swift          # On-device speech recognition & live transcript
    ├── VisionService.swift          # On-device image classification
    └── FoodDescriptionBuilder.swift # NLTagger noun extraction + Vision label cleaning
FoodLoggerTests/
    ├── FoodDescriptionBuilderTests.swift
    ├── FoodEntryModelTests.swift
    └── VisionServiceTests.swift
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

24 tests across 3 suites covering the data model, description builder, and Vision service.
