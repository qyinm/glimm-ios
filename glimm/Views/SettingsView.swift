//
//  SettingsView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
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
            ScrollView {
                VStack(spacing: 24) {
                    notificationSection

                    dataStorageSection

                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 100) // Space for tab bar
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Enable toggle
                    settingRow {
                        Toggle("Enable Notifications", isOn: Binding(
                            get: { settings.notifyEnabled },
                            set: { newValue in
                                settings.notifyEnabled = newValue
                                if newValue {
                                    Task {
                                        _ = await NotificationService.shared.requestPermission()
                                        await NotificationService.shared.scheduleRandomNotifications(settings: settings)
                                    }
                                } else {
                                    NotificationService.shared.cancelAllNotifications()
                                }
                            }
                        ))
                        .tint(.green)
                    }

                    if settings.notifyEnabled {
                        divider

                        // Start time
                        settingRow {
                            HStack {
                                Text("Start Time")
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { settings.notifyStart },
                                        set: {
                                            settings.notifyStart = $0
                                            rescheduleNotifications()
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                        }

                        divider

                        // End time
                        settingRow {
                            HStack {
                                Text("End Time")
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { settings.notifyEnd },
                                        set: {
                                            settings.notifyEnd = $0
                                            rescheduleNotifications()
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                        }

                        divider

                        // Frequency
                        settingRow {
                            HStack {
                                Text("Frequency: \(settings.notifyFrequency) per day")
                                Spacer()
                                HStack(spacing: 0) {
                                    Button {
                                        if settings.notifyFrequency > 1 {
                                            settings.notifyFrequency -= 1
                                            rescheduleNotifications()
                                        }
                                    } label: {
                                        Image(systemName: "minus")
                                            .frame(width: 44, height: 36)
                                    }

                                    Divider()
                                        .frame(height: 20)

                                    Button {
                                        if settings.notifyFrequency < 10 {
                                            settings.notifyFrequency += 1
                                            rescheduleNotifications()
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                            .frame(width: 44, height: 36)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }

            Text("glimm will send random reminders during your active hours to capture moments.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var dataStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Storage")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    settingRow {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 16))

                            Text("Your memories are stored locally on this device. Deleting the app will permanently remove all your data.")
                                .font(.callout)
                                .lineLimit(nil)

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    settingRow {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }
                    }

                    divider

                    settingRow {
                        Link(destination: URL(string: "https://glimm-landing-page.vercel.app/privacy")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    divider

                    settingRow {
                        Link(destination: URL(string: "https://glimm-landing-page.vercel.app/terms")!) {
                            HStack {
                                Text("Terms of Service")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func settingRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 16)
    }

    private func rescheduleNotifications() {
        Task {
            await NotificationService.shared.scheduleRandomNotifications(settings: settings)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Settings.self, inMemory: true)
}

#Preview("Dark Mode") {
    SettingsView()
        .modelContainer(for: Settings.self, inMemory: true)
        .preferredColorScheme(.dark)
}
