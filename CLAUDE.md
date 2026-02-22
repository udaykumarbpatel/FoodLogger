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
    App/FoodLoggerApp.swift       ← @main; AppDelegate (UIApplicationDelegate + UNUserNotificationCenterDelegate); quick actions; Notification.Name extensions (.quickAction, .openAddEntry, .openWeeklyRecap); AppRootView with Monday recap trigger
    Models/FoodEntry.swift
    Models/MealCategory.swift     ← enum MealCategory (breakfast/lunch/snack/dinner/dessert/beverage); has .color and .icon
    Views/AppShellView.swift      ← ROOT: outer TabView with 4 tabs (Today/Calendar/Insights/Settings); owns @Query allEntries; listens for .openWeeklyRecap → presents WeeklyRecapView as fullScreenCover
    Views/WeeklyRecapView.swift   ← 6-page fullScreenCover recap (Hero/Stats/TopFood/Categories/Consistency/Share); Canvas confetti on perfect week; ImageRenderer share card
    Views/TodayTabView.swift      ← Tab 1: NavigationStack wrapping DayLogView + gradient banner (greeting, streak, today count)
    Views/DayLogView.swift        ← swipe-between-days shell (DayLogView) + entry list body (DayLogBody); toolbar: search + today only
    Views/CalendarTabView.swift   ← Tab 2: full-screen calendar (month grid top half, inline day entries bottom half)
    Views/AddEntryView.swift      ← text/voice/image; edit mode via editingEntry: FoodEntry? param; capsule pill mode selector; .presentationDetents([.large])
    Views/EntryCardView.swift     ← card with colored left bar, cornerRadius 16, shadow; relative/absolute timestamp, category badge, "edited" label
    Views/CalendarView.swift      ← legacy month-grid sheet (kept for reference; navigation now uses CalendarTabView)
    Views/SearchView.swift        ← full-text search sheet; tapping a result navigates + highlights entry
    Views/SummaryView.swift       ← weekly/monthly grouped entry list sheet
    Views/SettingsView.swift      ← Tab 4: daily reminder toggle + time picker + JSON export; #if DEBUG "Clear Sample Data" section
    Views/InsightsView.swift      ← Tab 3: analytics dashboard: 8 Swift Charts cards + period picker
    Views/StyleGuide.swift        ← shared: Font extensions (.appBody/.appTitle/.appCaption/.appHeadline/.appSubheadline), CardModifier + .cardStyle(), EmptyStateView
    Services/SpeechService.swift
    Services/VisionService.swift
    Services/FoodDescriptionBuilder.swift
    Services/CategoryDetectionService.swift  ← @MainActor; detect(hour:description:visionLabels:)
    Services/StreakService.swift             ← struct; compute(from:[FoodEntry]) -> StreakInfo
    Services/NotificationService.swift      ← @MainActor; schedules 14 individual daily reminders (identifier "daily-reminder-{offset}"); scheduleWeeklyRecap(summary:) for Sunday 7pm (identifier "weekly-recap", repeats: true)
    Services/WeeklySummaryService.swift     ← @MainActor final class; generateSummary(from:) -> WeeklySummary; generateHeadline/generateSubheadline; HeadlineType enum (streak/topFood/improvement/perfect/default)
    Services/ExportService.swift            ← pure struct; jsonData(from:) + filename(for:); no actor isolation
    Services/InsightsService.swift          ← @MainActor final class; typed analytics over [FoodEntry]; see below
    Services/SampleDataService.swift        ← @MainActor final class; seedIfNeeded(context:) + seed(context:); 120 days of realistic sample data
  FoodLoggerTests/              ← test target (file-system sync root)
    FoodDescriptionBuilderTests.swift   (Swift Testing — 12 tests)
    FoodEntryModelTests.swift           (Swift Testing — 9 tests)
    VisionServiceTests.swift            (XCTest — Vision needs no timeout limit — 4 tests)
    MealCategoryTests.swift             (Swift Testing — 47 tests for CategoryDetectionService)
    ExportServiceTests.swift            (Swift Testing — 20 tests for ExportService)
    InsightsServiceTests.swift          (Swift Testing — 37 tests for InsightsService)
    SampleDataServiceTests.swift        (Swift Testing — 10 tests for SampleDataService)
    WeeklySummaryServiceTests.swift     (Swift Testing — 25 tests for WeeklySummaryService)
    NotificationRecapTests.swift        (Swift Testing — 15 tests for weekly recap notification)
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
- **InsightsServiceTests** (37 tests): every InsightsService method covered — topItems (frequency, stopword stripping, period filtering, limit), dailyCounts (gap-filling, period window), categoryDistribution (percentages, nil exclusion), inputTypeBreakdown, mealTiming (24-hour bins), weekOverWeekTrend (this/last week windows), monthlyHeatmap (all days filled), coOccurrence (same-day pairing)
- **SampleDataServiceTests** (10 tests): seeds when empty, no-op when data exists, all 6 categories, all 3 input types, no future dates, [SAMPLE] prefix on all rawInputs, date = startOfDay, count ≥ 70, deterministic output, `seed()` forces re-seed even when entries exist
- **VisionServiceTests** (4 tests) uses XCTest — Swift Testing's 1-second async timeout (caused by `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) kills Vision tests before the model initialises. `VNClassifyImageRequest` may not be available on the iOS 26.2 simulator beta; Vision tests skip gracefully rather than failing.
- SwiftData tests use `ModelConfiguration(isStoredInMemoryOnly: true)` for full isolation

## Navigation architecture (tab bar)
The app uses a **4-tab bottom tab bar** as the primary navigation structure:

- **Tab 1 — Today** (`TodayTabView`): `NavigationStack` wrapping `DayLogView`. Adds a gradient accent banner at the top via `.safeAreaInset(edge: .top)` showing greeting (good morning/afternoon/evening), friendly date, streak flame+count, and today's entry count.
- **Tab 2 — Calendar** (`CalendarTabView`): Full-screen calendar. Top half is a month grid; bottom half shows the selected day's entries inline in a `List`. Tapping a day updates `@State selectedDate` — no push navigation needed.
- **Tab 3 — Insights** (`InsightsView`): Analytics dashboard. `AppShellView` owns `@Query allEntries` and passes it directly.
- **Tab 4 — Settings** (`SettingsView`): Settings. `AppShellView` computes `hasLoggedToday` from `StreakService` and passes it.

`AppShellView` owns `@Query private var allEntries: [FoodEntry]` and a `StreakService` instance for computing data needed by child tabs.

## DayLogView architecture (Today tab content)
Uses a **shell + body** pattern inside a **`TabView` with page style** for swipe-based day navigation:

- **`DayLogView` (shell):** owns `@State var selectedIndex: Int` (the current page), streak badge, toolbar buttons (search only + today pill), and the search sheet. Calendar, Insights, Settings, and Summary are now dedicated tabs — not sheets from DayLogView.
- **Date range:** 366 pages total — index 0 = 365 days ago, index 365 = today (`todayIndex`). `referenceDate` and `todayIndex` are `private static let` computed once at launch. `displayedDate` is a computed property derived from `selectedIndex`.
- **Swipe navigation:** `TabView(selection: $selectedIndex)` with `.tabViewStyle(.page(indexDisplayMode: .never))`. Swiping left/right moves between days natively without conflicting with the list's swipe actions.
- **External navigation** (search, quick actions) updates `selectedIndex` with `withAnimation(.none)` for an instant jump.
- **`DayLogBody` (private struct):** receives `date`, `isToday`, `@Binding highlightedEntryID`. Owns a `@Query` with a day-range predicate set in `init()`. Handles the entry list, FAB, swipe actions, context menu, add/edit sheets, and toast. Uses `ScrollViewReader` + `.task(id: highlightedEntryID)` to scroll and highlight an entry selected from Search.
- Uses `List` (not LazyVStack) to enable `.swipeActions` for Edit (blue) and Delete (red, `allowsFullSwipe: true`)
- **Delete:** single action — no confirmation alert. `allowsFullSwipe: true` means a full left-swipe deletes immediately. Also removes associated image file from Documents. `UINotificationFeedbackGenerator(.warning)`.
- **Long-press `.contextMenu`:** Edit, duplicate ("I ate it today" when on a past day, "I ate again" when on today), Delete
- Duplicate: creates new FoodEntry for today; shows spring-animated Capsule toast for 2 seconds. `UIImpactFeedbackGenerator(.medium)`.

## AddEntryView architecture
- Parameters: `forDate: Date` (defaults to today's start-of-day) and `editingEntry: FoodEntry?` (nil = create, non-nil = edit)
- State initialised in `init()` via `_var = State(initialValue:)` pattern
- Presented as `.presentationDetents([.large])` with `.presentationDragIndicator(.visible)`
- Mode selector: custom `CapsuleModeSelector` (private struct) — rounded capsule pill with animated selection indicator; replaces the old `.pickerStyle(.segmented)` picker
- Edit mode: hides mode selector, shows editable TextEditor pre-filled with `processedDescription`, sets `entry.updatedAt = Date()` on save
- Category picker: `Picker` with `.menu` style; "Auto-detect" (nil) for create mode, "None" (nil) for edit mode; all 6 MealCategory cases listed
- On create: `selectedCategory ?? categoryService.detect(hour:description:visionLabels:)` — manual pick overrides auto-detect
- On edit: sets `entry.category = selectedCategory` (nil = removes tag)

## EntryCardView architecture
- Parameters: `entry: FoodEntry`, `isToday: Bool`, `isHighlighted: Bool = false`
- Layout: `HStack` with a thin colored left bar (4 pt wide, `entry.category?.color ?? .clear`, rounded corners) + content VStack
- Card style: `Color(UIColor.secondarySystemGroupedBackground)` background, `cornerRadius(16, .continuous)`, `shadow(opacity: 0.06, radius: 8, y: 4)`
- Timestamp: `Text(.relative)` when `isToday`, `Text(.time)` when not
- "· edited" italic caption shown when `entry.updatedAt != nil`
- Category badge is a tappable `Menu` — pick any MealCategory or "Remove Tag" (sets to nil)
- `isHighlighted`: renders an accent-color stroke overlay; used when navigating from Search

## StyleGuide architecture
`Views/StyleGuide.swift` — shared design tokens, no actor isolation needed:
- **`Font` extensions:** `.appBody`, `.appTitle`, `.appCaption`, `.appHeadline`, `.appSubheadline` — all use `.rounded` design
- **`CardModifier`:** `ViewModifier` applying `UIColor.secondarySystemGroupedBackground`, continuous `cornerRadius(16)`, shadow. Exposed as `.cardStyle()` on `View`.
- **`EmptyStateView`:** reusable struct with `symbol: String`, `message: String`, `subMessage: String?`. Used in `CalendarTabView` for empty day state.
- **Note:** `MealCategory.color` and `MealCategory.icon` are defined in `Models/MealCategory.swift` — do NOT redefine them in StyleGuide.swift.

## SettingsView architecture
- Three sections: **Notifications** (daily reminder toggle + time picker), **Data** (Export Data button), and **Developer** (`#if DEBUG` only — "Clear Sample Data" destructive button with confirmation alert)
- **Export flow:** fetches all `FoodEntry` records via `modelContext`, calls `ExportService.jsonData(from:)` + `ExportService.filename()`, writes to a temp file, then presents a `ShareSheet` (thin `UIActivityViewController` wrapper) via `.sheet(item: $exportItem)`. If no entries exist, shows a "Nothing to Export" alert instead.
- **Clear Sample Data (DEBUG):** fetches all entries, deletes those with `rawInput.hasPrefix("[SAMPLE]")`, saves, then calls `SampleDataService().seed(context:)` (unconditional — not `seedIfNeeded`) to guarantee re-seeding even when real entries coexist. Requires confirmation alert before deletion.
- `ExportItem`: private `Identifiable` struct wrapping the temp `URL`, used as the `.sheet(item:)` binding.
- `ShareSheet`: `UIViewControllerRepresentable` defined in `SettingsView.swift`; reusable if needed elsewhere.

## Service architecture
- **SpeechService**: `@Observable @MainActor` class. Uses a private `SpeechRecognizerDelegate: NSObject` bridge for AVAudioEngine/SFSpeechRecognizer callbacks. Configures AVAudioSession with `.record` category, `.measurement` mode, `.duckOthers`. Uses `#if targetEnvironment(simulator)` to disable on-device recognition on simulator.
- **VisionService**: `final class VisionService: Sendable` with **no actor isolation** — stateless wrapper; `nonisolated` async method runs Vision on `DispatchQueue.global(qos: .userInitiated)` via `withCheckedThrowingContinuation`. Filters results to confidence > 0.3, top 3 labels.
- **FoodDescriptionBuilder**: `@MainActor` stateless class. Text/voice paths use `NLTagger(.lexicalClass)` to extract nouns and adjectives; Vision path cleans labels (underscores → spaces, strips parenthetical qualifiers).
- **CategoryDetectionService**: `@MainActor final class`. Single method `detect(hour:description:visionLabels:) -> MealCategory`. All six categories have dedicated `Set<String>` keyword lists checked in priority order (beverage → dessert → breakfast → lunch → snack → dinner); a keyword match returns immediately with no time-bucket consultation. Time buckets (5–10 breakfast, 11–14 lunch, 15–16 snack, 17–20 dinner, else snack) are only reached when zero keywords match across description and visionLabels tokens. Uses `Set<String>` for O(1) lookup; tokenises by splitting on whitespace and commas, lowercased. Keyword sets include Indian/South Indian vocabulary (idli, dosa, biryani, lassi, samosa, tikka, kheer, etc.) so those foods are categorised by content rather than falling through to the time bucket.
- **StreakService**: `struct`. `compute(from: [FoodEntry]) -> StreakInfo` builds a `Set<Date>` of days with entries then counts consecutive days backward from today (or yesterday if no entry today).
- **NotificationService**: `@MainActor final class`. `scheduleReminders(at:hasLoggedToday:)` removes all pending requests then schedules 14 individual non-repeating `UNCalendarNotificationTrigger` notifications (one per day), skipping today if already logged and skipping past times. **Why 14:** iOS caps an app at 64 pending notifications; 14 covers two weeks of daily reminders while leaving ~50 slots free for other future notification types. The window is rescheduled from scratch on every call so it always stays current. `scheduleWeeklyRecap(summary:)` schedules a repeating Sunday 7pm notification (identifier `"weekly-recap"`) with `summary.headline` as the body, replacing any existing recap notification without disturbing daily reminders.
- **WeeklySummaryService**: `@MainActor final class`. `generateSummary(from: [FoodEntry]) -> WeeklySummary` computes Mon–Sun ISO week window, filters entries to this/last week, and returns a `WeeklySummary` with all analytics. `HeadlineType` priority: `.streak` (streak > 7) → `.topFood` (topFoodCount ≥ 3) → `.improvement` (vsLastWeek > 3) → `.perfect` (missedDays == 0) → `.default`. Tokeniser strips stopwords matching `InsightsService` and tokens shorter than 3 chars.
- **InsightsService**: `@MainActor final class`. Accepts `[FoodEntry]`, returns typed analytics structs. Key types: `AnalyticsPeriod` (week/month/threeMonths/year/allTime), `FoodItemFrequency`, `DailyCount`, `CategoryCount`, `InputTypeCount`, `HourCount`, `WeekComparison`, `DayActivity`, `ItemPair` (all `Identifiable` except `WeekComparison`). Methods: `topItems`, `dailyCounts`, `categoryDistribution`, `inputTypeBreakdown`, `mealTiming`, `weekOverWeekTrend`, `monthlyHeatmap`, `coOccurrence`. Strips stopwords: a, the, and, with, of, in, for, had, ate, some, my, an.
- **SampleDataService**: `@MainActor final class`. Two public methods: `seedIfNeeded(context:)` — no-op if any `FoodEntry` exists (used on first launch); `seed(context:)` — unconditional, always inserts a full batch (used by "Clear & Re-seed" in Settings). Seeds 120 days of data (~85% of days have 1–3 entries), all 6 categories, all 3 input types, 35+ realistic food items, every `rawInput` prefixed with `[SAMPLE]`. Uses deterministic LCG (`SeededRNG`) for reproducible output. Image entries have `mediaURL = nil`.

## InsightsView architecture
Presented as **Tab 3** in the bottom tab bar. `AppShellView` owns `@Query allEntries` and passes it as `entries: [FoodEntry]`.

- **Period picker:** segmented control at top (7D / 30D / 3M / 1Y / All) drives all time-sensitive charts via `@State selectedPeriod: AnalyticsPeriod`
- **Charts (Swift Charts only — no third-party deps):**
  - **Top Foods** — horizontal `BarMark`, top 10 food items by frequency
  - **Daily Activity** — `LineMark` + `AreaMark` fill over the selected period
  - **Categories** — donut `SectorMark` with `innerRadius: .ratio(0.6)`, total count center label, color per `MealCategory.color`
  - **Meal Timing** — vertical `BarMark` by hour, color-banded by time of day (orange/green/yellow/indigo)
  - **Week vs Last Week** — grouped `BarMark` with trend label (↑/↓ percentage, green/red)
  - **Monthly Consistency** — custom `LazyVGrid` 7-column heatmap (NOT Charts), accent-opacity scale for 0/1/2/3+ entries; previous/next month navigation via `@State heatmapMonth`
  - **Food Search** — `TextField` filtering `topItems(period: .allTime, limit: 100)`, shows name + count badge rows
  - **Stats Card** — streak count (flame icon), consistency % ring progress (Circle `.trim`), total entries count
- Every chart card handles empty data with an SF Symbol + message (no crashes on zero entries)
- All derived data computed as private computed vars from `entries + selectedPeriod` — no `@State` for analytics results

## App entry point & quick actions
`FoodLoggerApp.swift` uses `@UIApplicationDelegateAdaptor(AppDelegate.self)`. Root view is `AppRootView` (private struct), which renders `AppShellView()` and calls `SampleDataService().seedIfNeeded(context: modelContext)` once on launch via `.task`. `AppDelegate` registers two `UIApplicationShortcutItem`s on launch:
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
