# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Standing rule — keep docs in sync
**After every code change that adds, removes, or modifies a feature, architecture pattern, service, or user-facing behavior: update this file (CLAUDE.md) and README.md before considering the task complete.** Do not wait to be asked. This applies to any edit to a `.swift` file that affects how the app works.

## What this project is
Native iOS food diary app. Users log meals by text, voice, or photo. Plain-text descriptions only — no calories or macros. 100% on-device; zero network requests.

## Design language
Visual identity: **Dark Editorial Journal** — deep near-black backgrounds, cream serif typography for editorial moments, vivid orange accents. Journal meets food.

**Color palette** (defined in `StyleGuide.swift` as `Color` extensions):
| Token | Hex | Usage |
|---|---|---|
| `brandVoid` | `#070B18` | Near-black navy — primary page backgrounds (Today, Calendar, Insights) |
| `brandPrimary` | `#1B1F3B` | Deep navy — headers, secondary backgrounds, tab bar |
| `brandAccent` | `#FF6B35` | Vivid orange — CTAs, FAB, streaks, highlights, selected tab, category header bands |
| `brandWarm` | `#FFB347` | Amber — secondary accents, taglines, chart labels, ALL CAPS section headers |
| `brandSurface` | `#F7F3EE` | Warm off-white — text on dark backgrounds, day numbers, title text |
| `brandSuccess` | `#2ECC71` | Green — streaks, positive trends |

**Typography** — two type families:

*Rounded (functional UI):*
- `.appDisplay` — size 34, `.black` — hero numbers
- `.appTitle` — `.title2`, `.black` — section headers
- `.appHeadline` — `.headline`, `.bold` — card titles, labels
- `.appSubheadline` — `.subheadline`, `.medium`
- `.appBody` — `.body`, `.medium`
- `.appCaption` — `.caption`, `.regular`

*Serif (editorial moments — dates, month names, headlines, empty states):*
- `.appDisplaySerif` — size 34, `.black`, `.serif` — large hero serif text
- `.appTitleSerif` — `.title2`, `.bold`, `.serif` — section titles, day titles, empty states
- `.appHeadlineSerif` — `.headline`, `.bold`, `.serif` — panel headers, selected-day label
- **Note:** Correct parameter order for TextStyle overload is `Font.system(.textStyle, design: .serif, weight: .bold)` — `design` must come before `weight`.

**Graphic motif:** typographic wordmark — "YOUR FOOD." in cream/off-white bold serif (`.system(.serif, weight: .black)`), "YOUR STORY." in vivid orange bold italic serif. Background is near-black navy (`#070B18` ≈ `Color(red:0.028, green:0.043, blue:0.094)`), darker than `brandPrimary`. Used in `AppIconView` (1024×1024 canvas), `LaunchScreenView` (animated slide-up), and `OnboardingView` page 1.

**Tab bar:** deep navy background, vivid orange selected, 40%-white unselected. Configured via `UITabBar.appearance()` in `AppShellView.init()`.

**AccentColor asset:** set to `brandAccent` (#FF6B35) — propagates to all tint colors, toggles, pickers.

**Launch sequence (every launch):** `LaunchScreenView` (1.4s animated) → `AppShellView`. On first launch only: `OnboardingView` (4-page fullScreenCover) appears after the launch screen.

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
    App/FoodLoggerApp.swift       ← @main; AppDelegate; quick actions; Notification.Name extensions; AppRootView with launch sequence: LaunchScreenView (1.4s) → AppShellView + OnboardingView fullScreenCover (first launch only) + Monday recap trigger
    Views/OnboardingView.swift    ← 4-page fullScreenCover onboarding (Welcome/LogAnything/Patterns/Private); custom capsule page indicator; skip button; UserDefaults key "onboardingComplete"; shown once on first launch
    Views/LaunchScreenView.swift  ← animated launch screen: typographic wordmark ("YOUR FOOD." cream serif slides up, "YOUR STORY." orange italic serif follows, subtitle fades last); near-black navy background; calls onComplete after 1.4s; shown every launch
    Views/AppIconView.swift       ← SwiftUI reference view of the app icon design (1024×1024 canvas; near-black navy bg + "YOUR FOOD." cream serif + "YOUR STORY." orange italic serif); NO .clipShape — iOS applies its own mask so the PNG must be a full square; export via Settings → Developer → Export App Icon
    Views/AppShellView.swift      ← ROOT: ZStack(TabView + MilestoneOverlayView); 4 tabs (Today/Calendar/Insights/Settings); owns @Query allEntries + NotificationService; in init() configures UITabBar.appearance (navy bg, orange selected, dim-white unselected) AND UINavigationBar.appearance (brandVoid bg, cream title text, orange tint); TabView uses .toolbarColorScheme(.dark, for: .tabBar) + .preferredColorScheme(.dark) to force dark mode for the whole app (designed as a dark-only journal); listens for .openWeeklyRecap; tracks milestones + schedules streak-risk notification on entry count change
    Views/WeeklyRecapView.swift   ← 6-page fullScreenCover recap (Hero/Stats/TopFood/Categories/Consistency/Share); Canvas confetti on perfect week; ImageRenderer share card; ConfettiView + ConfettiParticle are now internal (not private) so AppShellView can reuse them
    Views/TodayTabView.swift      ← Tab 1: NavigationStack wrapping DayLogView + dark editorial banner (brandVoid bg, ALL CAPS amber greeting, appTitleSerif date, black-weight streak flame+count, caption entry count); orange accent rule 1pt at bottom; flame color: brandWarm <7, orange 7–13, red 14+
    Views/DayLogView.swift        ← swipe-between-days shell (DayLogView) + entry list body (DayLogBody); toolbar: search + today only; DayLogBody fires success haptic + contextual toast ("First entry today!" / "Meal #N today!") via .onChange(of: entries.count) when count increases on today's page
    Views/CalendarTabView.swift   ← Tab 2: full-screen calendar on brandVoid background; month header uses appDisplaySerif cream name + amber year + circular nav buttons; day-of-week row in amber rounded; day cells: heatmap (brandAccent opacity 0→0.22→0.50→0.80 for 0/1/2/3+ entries), selected=brandAccent fill, today=cream ring; brandAccent divider between grid and day panel; day entries panel uses appHeadlineSerif title; CalendarTabDayCell takes entryCount: Int
    Views/AddEntryView.swift      ← text/voice/image; edit mode via editingEntry: FoodEntry? param; capsule pill mode selector; .presentationDetents([.large])
    Views/EntryCardView.swift     ← card with full-width colored category header band (30pt, ALL CAPS icon+label, tappable Menu for category change) + dark body (brandVoid + category tint); cornerRadius 16; footer row with timestamp + "· edited"; colored shadow; brandAccent stroke when highlighted
    Views/CalendarView.swift      ← legacy month-grid sheet (kept for reference; navigation now uses CalendarTabView)
    Views/SearchView.swift        ← full-text search sheet; tapping a result navigates + highlights entry
    Views/SummaryView.swift       ← weekly/monthly grouped entry list sheet
    Views/SettingsView.swift      ← Tab 4: daily reminder toggle + time picker + JSON export; #if DEBUG "Clear Sample Data" + "Clear & Re-seed" section
    Views/InsightsView.swift      ← Tab 3: analytics dashboard on brandVoid background; storyHeadlineCard (ALL CAPS orange eyebrow, appTitleSerif headline, amber subheadline) above period picker; chartCard containers use ALL CAPS amber label + brandVoid bg + 3% surface tint + subtle border; statsCard + recordsCard + 8 Swift Charts cards; foodSearchCard rows are tappable Buttons that present FoodItemTimelineView as a sheet (@State selectedFoodItem: FoodItemFrequency?); all backgrounds use view-builder syntax `.background { ZStack{...} }` (not ShapeStyle — ZStack is not a ShapeStyle)
    Views/FoodItemTimelineView.swift ← Sheet presented from InsightsView food search card; shows occurrence timeline (BarMark per day), day-of-week pattern (Mon–Sun bar chart), and time-of-day distribution for a specific food item; has its own period picker (7D/30D/3M/1Y/All) and header stats row (total count, last eaten, count in period); uses same chartCard style as InsightsView
    Views/StyleGuide.swift        ← shared: Color(hex:) initializer + brand palette (brandVoid/brandPrimary/brandAccent/brandWarm/brandSurface/brandSuccess); Font extensions — rounded (.appBody/.appTitle/.appCaption/.appHeadline/.appSubheadline/.appDisplay) + serif (.appDisplaySerif/.appTitleSerif/.appHeadlineSerif); CardModifier (dark-mode aware) + .cardStyle(); EmptyStateView
    Services/SpeechService.swift
    Services/VisionService.swift
    Services/FoodDescriptionBuilder.swift
    Services/CategoryDetectionService.swift  ← @MainActor; detect(hour:description:visionLabels:)
    Services/StreakService.swift             ← struct; compute(from:[FoodEntry]) -> StreakInfo
    Services/NotificationService.swift      ← @MainActor; schedules 14 individual daily reminders (identifier "daily-reminder-{offset}"); scheduleWeeklyRecap(summary:) for Sunday 7pm (identifier "weekly-recap", repeats: true); scheduleStreakRisk(currentStreak:hasLoggedToday:) schedules/cancels an 8pm nudge (identifier "streak-risk") when streak > 0 and no entry today
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
  Marketing/                    ← App Store listing (appstore.md) and landing page (index.html); no build target
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

`AppShellView` owns `@Query private var allEntries: [FoodEntry]`, a `StreakService` instance, and a `NotificationService` instance for computing data needed by child tabs.

**Milestone system (in `AppShellView`):** Milestones = [10, 25, 50, 100, 250] total entries. On `.task` (first launch): any milestone already exceeded is pre-marked triggered so new users aren't flooded. On `.onChange(of: allEntries.count)`: if `oldCount < milestone <= newCount` and milestone not yet triggered, saves it to UserDefaults (`"triggeredMilestones"` key: `[Int]`), sets `activeMilestone`, and shows `MilestoneOverlayView` (confetti + message + "Awesome!" button). Only one milestone shown per count-change event (returns after first match). `MilestoneOverlayView` is a private struct in `AppShellView.swift`; reuses `ConfettiView` from `WeeklyRecapView.swift`.

**Streak-at-risk notification:** `AppShellView` calls `NotificationService.scheduleStreakRisk(currentStreak:hasLoggedToday:)` in `.task` and on every `allEntries.count` change. The notification fires at 8pm today if streak > 0 and no entry today; it is cancelled when the user logs.

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
- **Entry save celebration:** `.onChange(of: entries.count)` in `DayLogBody` — when count increases and `isToday`, fires `UINotificationFeedbackGenerator(.success)` and shows a contextual toast: "First entry today! 🎉" for count==1, "Meal #N today!" for subsequent entries.

## AddEntryView architecture
- Parameters: `forDate: Date` (defaults to today's start-of-day) and `editingEntry: FoodEntry?` (nil = create, non-nil = edit)
- State initialised in `init()` via `_var = State(initialValue:)` pattern
- Presented as `.presentationDetents([.large])` with `.presentationDragIndicator(.visible)`
- Mode selector: custom `CapsuleModeSelector` (private struct) — rounded capsule pill with animated selection indicator; replaces the old `.pickerStyle(.segmented)` picker
- Edit mode: hides mode selector, shows editable TextEditor pre-filled with `processedDescription`, sets `entry.updatedAt = Date()` on save
- Category picker: `Picker` with `.menu` style; "Auto-detect" (nil) for create mode, "None" (nil) for edit mode; all 6 MealCategory cases listed
- On create: `selectedCategory ?? categoryService.detect(hour:description:visionLabels:)` — manual pick overrides auto-detect
- On edit: sets `entry.category = selectedCategory` (nil = removes tag)
- **Time picker:** `@State private var entryTime: Date` — initialised smartly on create: today → `Date()` (current time), past day → `forDate` (midnight, so the user sets an intentional time); edit mode → `entry.createdAt`. `DatePicker` with `.hourAndMinute` components shown below the category picker in both modes. `resolvedCreatedAt(day:time:)` combines the year/month/day from `forDate` (or `entry.date`) with the hour/minute from `entryTime` and writes the result to `entry.createdAt` on save, preserving day-grouping while updating sort order within the day.

## EntryCardView architecture
Compact tile design — 4–5 cards visible on screen simultaneously without scrolling. Dark editorial style.

- Parameters: `entry: FoodEntry`, `isToday: Bool`, `isHighlighted: Bool = false`
- Layout: `VStack(spacing: 0)` with two zones clipped by `RoundedRectangle(cornerRadius: 16, .continuous)`:
  - **Category header band** (30pt tall): full-width solid `entry.category?.color` background (nil → `#95A5A6` gray); SF Symbol icon + ALL CAPS category name in white `.bold .caption`; entire band is a tappable `Menu` to change/remove the category
  - **Card body**: dark `Color.brandVoid` + `categoryColor.opacity(0.07)` tint (applied via view-builder `.background {}`); `processedDescription` in `.body .medium`, `.lineLimit(2)` default (expands on tap), `.minimumScaleFactor(0.85)`, `Color.brandSurface` foreground; **footer row**: timestamp in `brandSurface.opacity(0.5)`, "· edited" italic in `brandWarm` if `updatedAt != nil`, `›` chevron in `brandSurface.opacity(0.25)` right
- Shadow: `categoryColor.opacity(0.22)`, radius 8, y 3 — colored to match category
- Border: `categoryColor.opacity(0.18)` 1pt stroke; `brandAccent` 2pt stroke when `isHighlighted` (from Search)
- Tap on body toggles `@State isExpanded` — expands description + shows thumbnail and original input if applicable
- Expanded content: photo thumbnail (160pt height, cornerRadius 8) + original rawInput section when it differs from processedDescription
- All interactive elements have `accessibilityLabel`; decorative elements (icon, chevron) are `accessibilityHidden(true)`

## StyleGuide architecture
`Views/StyleGuide.swift` — shared design tokens, no actor isolation needed:
- **`Color` extensions:** `brandVoid` (#070B18), `brandPrimary` (#1B1F3B), `brandAccent` (#FF6B35), `brandWarm` (#FFB347), `brandSurface` (#F7F3EE), `brandSuccess` (#2ECC71)
- **`Font` extensions — rounded (functional UI):** `.appBody`, `.appTitle`, `.appCaption`, `.appHeadline`, `.appSubheadline`, `.appDisplay` — all use `.rounded` design
- **`Font` extensions — serif (editorial moments):** `.appDisplaySerif` (size 34, black), `.appTitleSerif` (.title2, bold), `.appHeadlineSerif` (.headline, bold) — all use `.serif` design. **Critical parameter order:** `Font.system(.textStyle, design: .serif, weight: .bold)` — `design` must precede `weight` in the TextStyle overload.
- **`CardModifier`:** `ViewModifier` applying `secondarySystemGroupedBackground` in dark mode / `brandSurface` in light mode, continuous `cornerRadius(16)`, shadow. Exposed as `.cardStyle()` on `View`.
- **`EmptyStateView`:** reusable struct with `symbol: String`, `message: String`, `subMessage: String?`. Circle bg + brandAccent icon + brandPrimary title.
- **Background pattern for dark views:** Use view-builder `.background { ZStack { Color.brandVoid; Color.brandSurface.opacity(0.03) }.clipShape(RoundedRectangle(...)) }` — **NOT** `.background(ZStack{...}, in:)` because `ZStack` is not a `ShapeStyle`.
- **Navigation bar theming pattern:** Every `NavigationStack` in a tab must add `.toolbarBackground(Color.brandVoid, for: .navigationBar)` + `.toolbarColorScheme(.dark, for: .navigationBar)` so the nav bar stays void-dark with cream title text. `UINavigationBar.appearance()` in `AppShellView.init()` sets the global default but SwiftUI's per-view toolbar modifiers take precedence and are more reliable in iOS 26.
- **Note:** `MealCategory.color` and `MealCategory.icon` are defined in `Models/MealCategory.swift` — do NOT redefine them in StyleGuide.swift.

## SettingsView architecture
- Three sections: **Notifications** (daily reminder toggle + time picker), **Data** (Export Data button), and **Developer** (`#if DEBUG` only — Export App Icon + two destructive data buttons with confirmation alerts)
- **Export flow:** fetches all `FoodEntry` records via `modelContext`, calls `ExportService.jsonData(from:)` + `ExportService.filename()`, writes to a temp file, then presents a `ShareSheet` (thin `UIActivityViewController` wrapper) via `.sheet(item: $exportItem)`. If no entries exist, shows a "Nothing to Export" alert instead.
- **Clear Sample Data (DEBUG):** fetches all entries, deletes those with `rawInput.hasPrefix("[SAMPLE]")`, saves. No re-seeding.
- **Export App Icon (DEBUG):** uses `ImageRenderer` to render `AppIconView()` at 1024×1024 (scale 1.0), encodes as PNG, writes to the temp directory, and presents it via the shared `ShareSheet`. The user saves the PNG and drags it into `Assets.xcassets/AppIcon.appiconset` in Xcode.
- **Clear & Re-seed (DEBUG):** calls `clearSampleData()` then `SampleDataService().seed(context:)` (unconditional — not `seedIfNeeded`) to guarantee re-seeding even when real entries coexist. Each action requires its own confirmation alert before proceeding.
- `ExportItem`: private `Identifiable` struct wrapping the temp `URL`, used as the `.sheet(item:)` binding.
- `ShareSheet`: `UIViewControllerRepresentable` defined in `SettingsView.swift`; reusable if needed elsewhere.

## Service architecture
- **SpeechService**: `@Observable @MainActor` class. Uses a private `SpeechRecognizerDelegate: NSObject` bridge for AVAudioEngine/SFSpeechRecognizer callbacks. Configures AVAudioSession with `.record` category, `.measurement` mode, `.duckOthers`. Uses `#if targetEnvironment(simulator)` to disable on-device recognition on simulator.
- **VisionService**: `final class VisionService: Sendable` with **no actor isolation** — stateless wrapper; `nonisolated` async method runs Vision on `DispatchQueue.global(qos: .userInitiated)` via `withCheckedThrowingContinuation`. Filters results to confidence > 0.3, top 3 labels.
- **FoodDescriptionBuilder**: `@MainActor` stateless class. Text/voice paths use `NLTagger(.lexicalClass)` to extract nouns and adjectives; Vision path cleans labels (underscores → spaces, strips parenthetical qualifiers).
- **CategoryDetectionService**: `@MainActor final class`. Single method `detect(hour:description:visionLabels:) -> MealCategory`. All six categories have dedicated `Set<String>` keyword lists checked in priority order (beverage → dessert → breakfast → lunch → snack → dinner); a keyword match returns immediately with no time-bucket consultation. Time buckets (5–10 breakfast, 11–14 lunch, 15–16 snack, 17–20 dinner, else snack) are only reached when zero keywords match across description and visionLabels tokens. Uses `Set<String>` for O(1) lookup; tokenises by splitting on whitespace and commas, lowercased. Keyword sets include Indian/South Indian vocabulary (idli, dosa, biryani, lassi, samosa, tikka, kheer, etc.) so those foods are categorised by content rather than falling through to the time bucket.
- **StreakService**: `struct`. `compute(from: [FoodEntry]) -> StreakInfo` builds a `Set<Date>` of days with entries then counts consecutive days backward from today (or yesterday if no entry today).
- **NotificationService**: `@MainActor final class`. `scheduleReminders(at:hasLoggedToday:)` removes all pending requests then schedules 14 individual non-repeating `UNCalendarNotificationTrigger` notifications (one per day), skipping today if already logged and skipping past times. **Why 14:** iOS caps an app at 64 pending notifications; 14 covers two weeks of daily reminders while leaving ~50 slots free for other future notification types. The window is rescheduled from scratch on every call so it always stays current. `scheduleWeeklyRecap(summary:)` schedules a repeating Sunday 7pm notification (identifier `"weekly-recap"`) with `summary.headline` as the body, replacing any existing recap notification without disturbing daily reminders. `scheduleStreakRisk(currentStreak:hasLoggedToday:)` schedules a one-off 8pm notification (identifier `"streak-risk"`) if streak > 0 and no entry today; cancels it when already logged or streak is zero.
- **WeeklySummaryService**: `@MainActor final class`. `generateSummary(from: [FoodEntry]) -> WeeklySummary` computes Mon–Sun ISO week window, filters entries to this/last week, and returns a `WeeklySummary` with all analytics. `HeadlineType` priority: `.streak` (streak > 7) → `.topFood` (topFoodCount ≥ 3) → `.improvement` (vsLastWeek > 3) → `.perfect` (missedDays == 0) → `.default`. Tokeniser strips stopwords matching `InsightsService` and tokens shorter than 3 chars.
- **InsightsService**: `@MainActor final class`. Accepts `[FoodEntry]`, returns typed analytics structs. Key types: `AnalyticsPeriod` (week/month/threeMonths/year/allTime), `FoodItemFrequency`, `DailyCount`, `CategoryCount`, `InputTypeCount`, `HourCount`, `WeekComparison`, `DayActivity`, `ItemPair`, `WeekdayCount` (all `Identifiable` except `WeekComparison`). General methods: `topItems`, `dailyCounts`, `categoryDistribution`, `inputTypeBreakdown`, `mealTiming`, `weekOverWeekTrend`, `monthlyHeatmap`, `coOccurrence`. Food item timeline methods: `entriesMatching(term:from:)` (case-insensitive substring match), `itemDailyCounts(for:from:period:)` (gap-filled daily occurrence counts), `itemMealTiming(for:from:period:)` (hour-of-day distribution), `itemWeekdayPattern(for:from:period:)` (Mon–Sun occurrence counts as `[WeekdayCount]`). Strips stopwords: a, the, and, with, of, in, for, had, ate, some, my, an.
- **SampleDataService**: `@MainActor final class`. Two public methods: `seedIfNeeded(context:)` — no-op if any `FoodEntry` exists (used on first launch); `seed(context:)` — unconditional, always inserts a full batch (used by "Clear & Re-seed" in Settings). Seeds 120 days of data (~85% of days have 1–3 entries), all 6 categories, all 3 input types, 35+ realistic food items, every `rawInput` prefixed with `[SAMPLE]`. Uses deterministic LCG (`SeededRNG`) for reproducible output. Image entries have `mediaURL = nil`.

## InsightsView architecture
Presented as **Tab 3** in the bottom tab bar. `AppShellView` owns `@Query allEntries` and passes it as `entries: [FoodEntry]`. Background: `Color.brandVoid` on the `NavigationStack` and `ScrollView`.

- **Story headline card:** rendered first, above the period picker. Calls `WeeklySummaryService().generateSummary(from: entries)` on `.onAppear`. Card design: ALL CAPS `brandAccent` eyebrow label + `appTitleSerif` headline in `brandSurface` + amber subheadline. Uses view-builder `.background {}` with `ZStack` on `brandVoid`. Refreshes each time the tab becomes visible.
- **Period picker:** segmented control (7D / 30D / 3M / 1Y / All) drives all time-sensitive charts via `@State selectedPeriod: AnalyticsPeriod`
- **Cards rendered in order:** storyHeadlineCard → periodPicker → statsCard → recordsCard → topFoodsCard → dailyActivityCard → categoryCard → mealTimingCard → weekTrendCard → heatmapCard → foodSearchCard
- **Food Item Timeline drill-down:** Tapping any row in foodSearchCard presents `FoodItemTimelineView` as a sheet (`@State selectedFoodItem: FoodItemFrequency?`, `.sheet(item: $selectedFoodItem)`). The timeline view shows 3 charts — occurrence over time (bar per day), day-of-week pattern (Mon–Sun bars), and time-of-day distribution — all driven by `InsightsService` food-item methods with an independent period picker.
- **Charts (Swift Charts only — no third-party deps):**
  - **Stats Card** — streak count (flame icon), consistency % ring progress (Circle `.trim`), total entries in period
  - **Records Card** — longest streak ever (all-time), best single day count, total unique foods (all-time non-stopword tokens)
  - **Top Foods** — horizontal `BarMark`, top 10 food items by frequency
  - **Daily Activity** — `LineMark` + `AreaMark` fill over the selected period
  - **Categories** — donut `SectorMark` with `innerRadius: .ratio(0.6)`, total count center label, color per `MealCategory.color`
  - **Meal Timing** — vertical `BarMark` by hour, color-banded by time of day (orange/green/yellow/indigo)
  - **Week vs Last Week** — grouped `BarMark` with trend label (↑/↓ percentage, green/red)
  - **Monthly Consistency** — custom `LazyVGrid` 7-column heatmap (NOT Charts), accent-opacity scale for 0/1/2/3+ entries; previous/next month navigation via `@State heatmapMonth`
  - **Food Search** — `TextField` filtering `topItems(period: .allTime, limit: 100)`, shows name + count badge rows
- Every chart card handles empty data with an SF Symbol + message (no crashes on zero entries)
- `longestStreak`, `mostLoggedDayCount`, `totalUniqueFoods` computed all-time from the full `entries` array — not filtered by `selectedPeriod`
- `weeklySummary: WeeklySummary?` is `@State` refreshed in `.onAppear`; `summaryService = WeeklySummaryService()` is a `let` property

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

## UserDefaults keys

| Key | Type | Set by | Purpose |
|-----|------|--------|---------|
| `"onboardingComplete"` | `Bool` | `OnboardingView` | Set to `true` after first-launch onboarding is dismissed; gates whether OnboardingView shows |
| `"triggeredMilestones"` | `[Int]` | `AppShellView` | List of milestone counts (10/25/50/100/250) already shown; prevents repeat confetti overlays. Pre-populated with already-exceeded milestones on first launch to avoid flooding new users. |

## Frameworks
All Apple first-party, all auto-linked. **The Frameworks build phase is intentionally empty** — do not add frameworks there.
