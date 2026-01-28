//
//  SettingsView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [Settings]

    private var settings: Settings {
        if let existing = settingsArray.first {
            return existing
        }
        let newSettings = Settings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        NavigationStack {
            List {
                notificationSection

                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("Enable Notifications", isOn: Binding(
                get: { settings.notifyEnabled },
                set: { newValue in
                    settings.notifyEnabled = newValue
                    if newValue {
                        Task {
                            await NotificationService.shared.requestPermission()
                            await NotificationService.shared.scheduleRandomNotifications(settings: settings)
                        }
                    } else {
                        NotificationService.shared.cancelAllNotifications()
                    }
                }
            ))

            if settings.notifyEnabled {
                DatePicker(
                    "Start Time",
                    selection: Binding(
                        get: { settings.notifyStart },
                        set: { settings.notifyStart = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )

                DatePicker(
                    "End Time",
                    selection: Binding(
                        get: { settings.notifyEnd },
                        set: { settings.notifyEnd = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )

                Stepper(
                    "Frequency: \(settings.notifyFrequency) per day",
                    value: Binding(
                        get: { settings.notifyFrequency },
                        set: { settings.notifyFrequency = $0 }
                    ),
                    in: 1...5
                )
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("glimm will send random reminders during your active hours to capture moments.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://glimm.app/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Link(destination: URL(string: "https://glimm.app/terms")!) {
                HStack {
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Settings.self, inMemory: true)
}
