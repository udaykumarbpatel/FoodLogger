# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Standing rule — keep docs in sync
**After every code change that adds, removes, or modifies a feature, architecture pattern, service, or user-facing behavior: update this file (CLAUDE.md) and README.md before considering the task complete.** Do not wait to be asked. This applies to any edit to a `.swift` file that affects how the app works.

## What this project is
Native iOS food diary app. Users log meals by text, voice, or photo. Plain-text descriptions only — no calories or macros. 100% on-device; zero network requests.

## Tech stack
- **Language:** Swift 5, SwiftUI, SwiftData
- **On-device AI:** `Speech` (SFSpeechRecognizer), `Vision` (VNClassifyImageRequest), `NaturalLanguage` (NLTagger)
- **Xcode:** 26.2 — uses file-system-synchronized project (objectVersion = 77), so new files in subdirectories are auto-compiled without editing pbxproj
- **Deployment target:** iOS 26.2

## Critical concurrency constraints
The project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` in build settings (Swift 6 strict concurrency).

Rules that must be followed:
1. **`@Observable` and `NSObject` cannot be combined.** Use a private `NSObject` bridge for any ObjC delegates; the `@Observable` class stays pure Swift.
2. **`ObservableObject` / `@Published` require `import Combine`.** In this project Combine is not auto-imported. Use `@Observable` macro instead; pair with `@State` in views (not `@StateObject`).
3. **Blocking work must leave the main actor.** `VNImageRequestHandler.perform()` and similar sync APIs must run via `DispatchQueue.global()` inside `withCheckedThrowingContinuation`, NOT via `Task.detached` (which can be cancelled by the test runner).
4. **Delegate methods from non-`@MainActor` protocols must be `nonisolated`** and dispatch back with `Task { @MainActor in ... }`.

## Data model
```swift
// Models/FoodEntry.swift
enum InputType: String, Codable, CaseIterable { case text, image, voice }

@Model final class FoodEntry {
    var id: UUID
    var date: Date            // Always Calendar.current.startOfDay(for:) — never raw timestamp
    var rawInput: String
    var inputType: InputType
    var processedDescription: String
    var mediaURL: URL?        // Stored as URL(string: filename)! — bare filename only, e.g. "uuid.jpg"
    var createdAt: Date
    var category: MealCategory?   // Auto-detected on create; user can override in card or Add Entry sheet
    var updatedAt: Date?          // Set when an entry is edited; nil on initial creation
}
```

**Date rule:** Always store `date` as `Calendar.current.startOfDay(for: Date())`. Use range predicates (`>= start && < end`), never equality.

**mediaURL rule:** Store only the bare filename as `URL(string: filename)!`. Reconstruct absolute path at read time:
```swift
let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let absolute = docsDir.appendingPathComponent(mediaURL.absoluteString) // use .absoluteString, NOT .path
```
**Why `.absoluteString` and not `.path`:** SwiftData may internally normalise a bare `URL(string: "uuid.jpg")` into a `file://` URL when persisting. If `.path` were used on a `file://` URL it would return the full absolute path (e.g. `"/var/mobile/.../Documents/uuid.jpg"`), and `appendingPathComponent` of that would produce a doubled, broken path. `.absoluteString` always returns the original string passed to `URL(string:)` — just the bare filename — making reconstruction safe regardless of how SwiftData stores the value.

## Project structure
```
FoodLogger/                     ← git root & Xcode project root
  FoodLogger/                   ← app source (file-system sync root)
    App/FoodLoggerApp.swift       ← @main; AppDelegate for quick actions; Notification.Name extensions
    Models/FoodEntry.swift
    Models/MealCategory.swift     ← enum MealCategory (breakfast/lunch/snack/dinner/dessert/beverage)
    Views/DayLogView.swift        ← HOME SCREEN: shell (DayLogView) + body (DayLogBody)
    Views/AddEntryView.swift      ← text/voice/image; edit mode via editingEntry: FoodEntry? param
    Views/EntryCardView.swift     ← card with relative/absolute timestamp, category badge, "edited" label
    Views/CalendarView.swift      ← month-grid sheet; tapping a day navigates DayLogView to that date
    Views/SearchView.swift        ← full-text search sheet; tapping a result navigates + highlights entry
    Views/SummaryView.swift       ← weekly/monthly grouped entry list sheet
    Views/SettingsView.swift      ← daily reminder toggle + time picker + JSON export via ShareSheet
    Services/SpeechService.swift
    Services/VisionService.swift
    Services/FoodDescriptionBuilder.swift
    Services/CategoryDetectionService.swift  ← @MainActor; detect(hour:description:visionLabels:)
    Services/StreakService.swift             ← struct; compute(from:[FoodEntry]) -> StreakInfo
    Services/NotificationService.swift      ← @MainActor; schedules 14 individual daily reminders
    Services/ExportService.swift            ← pure struct; jsonData(from:) + filename(for:); no actor isolation
  FoodLoggerTests/              ← test target (file-system sync root)
    FoodDescriptionBuilderTests.swift   (Swift Testing — 12 tests)
    FoodEntryModelTests.swift           (Swift Testing — 9 tests)
    VisionServiceTests.swift            (XCTest — Vision needs no timeout limit — 4 tests)
    MealCategoryTests.swift             (Swift Testing — 47 tests for CategoryDetectionService)
    ExportServiceTests.swift            (Swift Testing — 20 tests for ExportService)
  FoodLogger.xcodeproj/
```

## Running & testing
```bash
# Build
xcodebuild -scheme FoodLogger -destination "platform=iOS Simulator,name=iPhone 17 Pro" build

# Run all tests
xcodebuild test -scheme FoodLogger -destination "platform=iOS Simulator,name=iPhone 17 Pro"

# Run a single test class
xcodebuild test -scheme FoodLogger -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:FoodLoggerTests/MealCategoryTests

# Run a single test method
xcodebuild test -scheme FoodLogger -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:FoodLoggerTests/FoodDescriptionBuilderTests/testEmptyInput
```

All simulators run iOS 26.2; use `iPhone 17 Pro` for development.

## Permissions
Defined in pbxproj build settings (not a separate Info.plist). Search for `INFOPLIST_KEY_NS` in the xcodeproj to find/modify them.

## Test suite notes
All tests use Swift Testing (`@Test`, `#expect`) and `@MainActor` unless noted:
- **FoodDescriptionBuilderTests** (12 tests): NLTagger noun/adjective extraction for text, voice, and image paths; empty and edge-case inputs
- **FoodEntryModelTests** (9 tests): SwiftData round-trip (in-memory store), date normalisation, `mediaURL` bare-filename rule, `updatedAt` lifecycle
- **MealCategoryTests** (47 tests): all six keyword categories, keyword-over-time-bucket priority, each time-bucket fallback, case-insensitive tokenisation, Vision label pass-through, Indian/South Indian food vocabulary (idli, dosa, biryani, lassi, samosa, tikka, kheer, etc.)
- **ExportServiceTests** (20 tests): valid JSON, all required fields present, field values (id, inputType, category rawValues), NSNull for nil optional fields, ISO 8601 date format, empty array, multiple entries, filename format and prefix
- **VisionServiceTests** (4 tests) uses XCTest — Swift Testing's 1-second async timeout (caused by `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) kills Vision tests before the model initialises. `VNClassifyImageRequest` may not be available on the iOS 26.2 simulator beta; Vision tests skip gracefully rather than failing.
- SwiftData tests use `ModelConfiguration(isStoredInMemoryOnly: true)` for full isolation

## DayLogView architecture (home screen)
Uses a **shell + body** pattern inside a **`TabView` with page style** for swipe-based day navigation:

- **`DayLogView` (shell):** owns `@State var selectedIndex: Int` (the current page, replaces `displayedDate`), `@Query var allEntries` (all entries, for streak), streak badge, toolbar buttons (search, calendar, ellipsis menu for summary/settings, today), and all sheet presentations.
- **Date range:** 366 pages total — index 0 = 365 days ago, index 365 = today (`todayIndex`). `referenceDate` and `todayIndex` are `private static let` computed once at launch. `displayedDate` is a computed property derived from `selectedIndex`.
- **Swipe navigation:** `TabView(selection: $selectedIndex)` with `.tabViewStyle(.page(indexDisplayMode: .never))`. Swiping left/right moves between days natively without conflicting with the list's swipe actions.
- **External navigation** (calendar picker, search, summary, quick actions) updates `selectedIndex` with `withAnimation(.none)` for an instant jump rather than a slow animated scroll across many pages.
- **`DayLogBody` (private struct):** receives `date`, `isToday`, `@Binding highlightedEntryID`. Owns a `@Query` with a day-range predicate set in `init()`. Handles the entry list, FAB, swipe actions, context menu, add/edit sheets, and toast. Uses `ScrollViewReader` + `.task(id: highlightedEntryID)` to scroll and highlight an entry selected from Search.
- Uses `List` (not LazyVStack) to enable `.swipeActions` for Edit (blue) and Delete (red, `allowsFullSwipe: true`)
- **Delete:** single action — no confirmation alert. `allowsFullSwipe: true` means a full left-swipe deletes immediately. Also removes associated image file from Documents. `UINotificationFeedbackGenerator(.warning)`.
- **Long-press `.contextMenu`:** Edit, duplicate ("I ate it today" when on a past day, "I ate again" when on today), Delete
- Duplicate: creates new FoodEntry for today; shows spring-animated Capsule toast for 2 seconds. `UIImpactFeedbackGenerator(.medium)`.

## AddEntryView architecture
- Parameters: `forDate: Date` (defaults to today's start-of-day) and `editingEntry: FoodEntry?` (nil = create, non-nil = edit)
- State initialised in `init()` via `_var = State(initialValue:)` pattern
- Edit mode: hides mode selector, shows editable TextEditor pre-filled with `processedDescription`, sets `entry.updatedAt = Date()` on save
- Category picker: `Picker` with `.menu` style; "Auto-detect" (nil) for create mode, "None" (nil) for edit mode; all 6 MealCategory cases listed
- On create: `selectedCategory ?? categoryService.detect(hour:description:visionLabels:)` — manual pick overrides auto-detect
- On edit: sets `entry.category = selectedCategory` (nil = removes tag)

## EntryCardView architecture
- Parameters: `entry: FoodEntry`, `isToday: Bool`, `isHighlighted: Bool = false`
- Timestamp: `Text(.relative)` when `isToday`, `Text(.time)` when not
- "· edited" italic caption shown when `entry.updatedAt != nil`
- Category badge is a tappable `Menu` — pick any MealCategory or "Remove Tag" (sets to nil)
- `isHighlighted`: renders an accent-color stroke overlay; used when navigating from Search

## SettingsView architecture
- Two sections: **Notifications** (daily reminder toggle + time picker) and **Data** (Export Data button)
- **Export flow:** fetches all `FoodEntry` records via `modelContext`, calls `ExportService.jsonData(from:)` + `ExportService.filename()`, writes to a temp file, then presents a `ShareSheet` (thin `UIActivityViewController` wrapper) via `.sheet(item: $exportItem)`. If no entries exist, shows an "Nothing to Export" alert instead.
- `ExportItem`: private `Identifiable` struct wrapping the temp `URL`, used as the `.sheet(item:)` binding.
- `ShareSheet`: `UIViewControllerRepresentable` defined in `SettingsView.swift`; reusable if needed elsewhere.

## Service architecture
- **SpeechService**: `@Observable @MainActor` class. Uses a private `SpeechRecognizerDelegate: NSObject` bridge for AVAudioEngine/SFSpeechRecognizer callbacks. Configures AVAudioSession with `.record` category, `.measurement` mode, `.duckOthers`. Uses `#if targetEnvironment(simulator)` to disable on-device recognition on simulator.
- **VisionService**: `final class VisionService: Sendable` with **no actor isolation** — stateless wrapper; `nonisolated` async method runs Vision on `DispatchQueue.global(qos: .userInitiated)` via `withCheckedThrowingContinuation`. Filters results to confidence > 0.3, top 3 labels.
- **FoodDescriptionBuilder**: `@MainActor` stateless class. Text/voice paths use `NLTagger(.lexicalClass)` to extract nouns and adjectives; Vision path cleans labels (underscores → spaces, strips parenthetical qualifiers).
- **CategoryDetectionService**: `@MainActor final class`. Single method `detect(hour:description:visionLabels:) -> MealCategory`. All six categories have dedicated `Set<String>` keyword lists checked in priority order (beverage → dessert → breakfast → lunch → snack → dinner); a keyword match returns immediately with no time-bucket consultation. Time buckets (5–10 breakfast, 11–14 lunch, 15–16 snack, 17–20 dinner, else snack) are only reached when zero keywords match across description and visionLabels tokens. Uses `Set<String>` for O(1) lookup; tokenises by splitting on whitespace and commas, lowercased. Keyword sets include Indian/South Indian vocabulary (idli, dosa, biryani, lassi, samosa, tikka, kheer, etc.) so those foods are categorised by content rather than falling through to the time bucket.
- **StreakService**: `struct`. `compute(from: [FoodEntry]) -> StreakInfo` builds a `Set<Date>` of days with entries then counts consecutive days backward from today (or yesterday if no entry today).
- **NotificationService**: `@MainActor final class`. `scheduleReminders(at:hasLoggedToday:)` removes all pending requests then schedules 14 individual non-repeating `UNCalendarNotificationTrigger` notifications (one per day), skipping today if already logged and skipping past times. **Why 14:** iOS caps an app at 64 pending notifications; 14 covers two weeks of daily reminders while leaving ~50 slots free for other future notification types. The window is rescheduled from scratch on every call so it always stays current.

## App entry point & quick actions
`FoodLoggerApp.swift` uses `@UIApplicationDelegateAdaptor(AppDelegate.self)`. `AppDelegate` registers two `UIApplicationShortcutItem`s on launch:
- **"Log Food Now"** (`com.foodlogger.quicklog`): posts `Notification.Name.quickAction` with `"addEntry"` → `DayLogView` navigates to today and opens the Add Entry sheet
- **"View Today"** (`com.foodlogger.viewtoday`): posts `Notification.Name.quickAction` with `"viewToday"` → `DayLogView` navigates to today

`Notification.Name` extensions (`.quickAction`, `.openAddEntry`) are defined in `FoodLoggerApp.swift`.

`FoodLoggerApp.swift` also contains a `#if DEBUG` block that catches a `ModelContainer` creation failure, deletes the corrupted store, and retries once. This is intentional defensive code — do not remove it.

## AddEntryView — AI-processing flow

### Voice mode
- User records → live transcript shown in `speechService.transcript`
- When `isRecording` flips false → `processVoiceTranscript()` copies raw transcript directly into `voiceEditableDescription` (no NLTagger extraction — keeps the full natural speech as-is)
- Editable `TextEditor` (accent-tinted border) appears immediately; Save button enables as soon as it's non-empty
- User can edit or tap Save as-is: `rawInput = speechService.transcript`, `processedDescription = voiceEditableDescription`
- Re-recording clears `voiceEditableDescription` and restarts the flow
- Permission denied → Settings alert via `showPermissionDenied(title:message:)`

### Image mode
- User picks photo → `onChange(of: selectedImage)` triggers `processImage(_:)` async
- Vision runs via `visionService.classifyImage(_:)` on global queue; `isProcessingImage` shows progress indicator
- `imageEditableDescription` and `storedVisionLabels` (State) are populated
- Editable `TextEditor` (accent-tinted border) appears; user edits, then saves
- `processedDescription = imageEditableDescription`, `rawInput = bare_filename`
- `storedVisionLabels` passed to `categoryService.detect()` for auto-detection
- Camera button calls `openCamera()` — checks `AVCaptureDevice` auth, requests if undetermined, shows Settings alert if denied

## Known simulator limitations
- `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` fails on simulator → guarded with `#if targetEnvironment(simulator)` to fall back to server recognition
- `VNClassifyImageRequest` may be unavailable on the iOS 26.2 simulator beta

## Frameworks
All Apple first-party, all auto-linked. **The Frameworks build phase is intentionally empty** — do not add frameworks there.
