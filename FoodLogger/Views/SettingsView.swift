import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    let hasLoggedToday: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let notificationService = NotificationService()

    @State private var remindersEnabled: Bool
    @State private var reminderTime: Date
    @State private var showPermissionDeniedAlert = false
    @State private var showEmptyExportAlert = false
    @State private var exportItem: ExportItem?

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
                // MARK: Notifications
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

                // MARK: Data
                Section {
                    Button("Export Data") {
                        exportAllEntries()
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Exports all entries as a JSON file you can save or share.")
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
            .alert("Nothing to Export", isPresented: $showEmptyExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You haven't logged any entries yet.")
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(activityItems: [item.url])
            }
        }
    }

    // MARK: - Export

    private func exportAllEntries() {
        let descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let entries = (try? modelContext.fetch(descriptor)) ?? []

        guard !entries.isEmpty else {
            showEmptyExportAlert = true
            return
        }

        guard let data = try? ExportService.jsonData(from: entries) else { return }

        let filename = ExportService.filename()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        exportItem = ExportItem(url: url)
    }

    // MARK: - Notifications

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

// MARK: - Helpers

/// Identifiable wrapper so .sheet(item:) can present the share sheet
private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Thin UIViewControllerRepresentable wrapping UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
