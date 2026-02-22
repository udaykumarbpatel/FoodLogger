import SwiftUI
import UserNotifications

struct SettingsView: View {
    let hasLoggedToday: Bool

    @Environment(\.dismiss) private var dismiss

    private let notificationService = NotificationService()

    @State private var remindersEnabled: Bool
    @State private var reminderTime: Date
    @State private var showPermissionDeniedAlert = false

    init(hasLoggedToday: Bool) {
        self.hasLoggedToday = hasLoggedToday
        let defaults = UserDefaults.standard
        _remindersEnabled = State(initialValue: defaults.bool(forKey: "remindersEnabled"))
        let storedTime = defaults.object(forKey: "reminderTime") as? Date
        _reminderTime = State(initialValue: storedTime ?? SettingsView.defaultReminderTime)
    }

    private static var defaultReminderTime: Date {
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily Reminder", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            Task { await applyNotificationSettings(enabled: enabled) }
                        }

                    if remindersEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { _, _ in
                            Task { await applyNotificationSettings(enabled: remindersEnabled) }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    if remindersEnabled {
                        Text("You'll be reminded each day unless you've already logged a meal.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to receive daily reminders.")
            }
        }
    }

    private func applyNotificationSettings(enabled: Bool) async {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "remindersEnabled")
        defaults.set(reminderTime, forKey: "reminderTime")

        if enabled {
            let granted = await notificationService.requestPermission()
            if granted {
                await notificationService.scheduleReminders(at: reminderTime, hasLoggedToday: hasLoggedToday)
            } else {
                remindersEnabled = false
                defaults.set(false, forKey: "remindersEnabled")
                showPermissionDeniedAlert = true
            }
        } else {
            notificationService.cancelAll()
        }
    }
}
