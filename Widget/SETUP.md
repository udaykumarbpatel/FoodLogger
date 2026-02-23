# Widget Extension Setup

The widget source is ready. To activate it:

1. In Xcode, File > New > Target > Widget Extension
2. Name it `FoodLoggerWidget`, bundle ID `com.ashwath.ios.FoodLogger.Widget`
3. **Uncheck** "Include Configuration App Intent" and "Include Live Activity"
4. Delete the generated Swift file Xcode creates
5. Add `FoodLoggerWidget.swift` (this directory) to the new target
6. Add App Group capability to BOTH the main app target AND the widget target:
   - Group ID: `group.com.ashwath.ios.FoodLogger`
7. Add the entitlement file to the widget target
8. In `AppShellView.swift`, the app already writes streak + today count to the shared UserDefaults -- no further app changes needed.

## Deep link handling

The widget taps open `foodlogger://addEntry`. The app already handles this via
`Notification.Name.openAddEntry`. To wire up the URL scheme:

- In Xcode, select the main app target > Info > URL Types > add `foodlogger` scheme
- In `FoodLoggerApp.swift`, add `.onOpenURL { url in ... }` to handle `foodlogger://addEntry`
