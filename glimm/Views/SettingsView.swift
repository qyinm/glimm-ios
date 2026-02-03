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
    @Query(sort: \Memory.capturedAt, order: .reverse) private var memories: [Memory]
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    // Export state
    @State private var isExporting = false
    @State private var exportProgress: String = ""
    @State private var showExportAlert = false
    @State private var exportAlertTitle = ""
    @State private var exportAlertMessage = ""
    @State private var zipFileURL: URL?
    @State private var showShareSheet = false

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

                    languageSection

                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 100) // Space for tab bar
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "settings.notifications"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Enable toggle
                    settingRow {
                        Toggle(String(localized: "settings.notifications.enable"), isOn: Binding(
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
                                Text(String(localized: "settings.notifications.startTime"))
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
                                Text(String(localized: "settings.notifications.endTime"))
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
                                Text("settings.notifications.frequency \(settings.notifyFrequency)", bundle: .main)
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

            Text(String(localized: "settings.notifications.description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var dataStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "settings.dataStorage"))
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

                            Text(String(localized: "settings.dataStorage.warning"))
                                .font(.callout)
                                .lineLimit(nil)

                            Spacer(minLength: 0)
                        }
                    }

                    divider

                    // Export to Photos Album
                    settingRow {
                        Button {
                            exportToPhotos()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "settings.export.photos"))
                                        .foregroundStyle(.primary)
                                    Text(String(localized: "settings.export.photos.description"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(isExporting || memories.isEmpty)
                    }

                    divider

                    // Create ZIP Backup
                    settingRow {
                        Button {
                            createBackup()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "settings.export.zip"))
                                        .foregroundStyle(.primary)
                                    Text(String(localized: "settings.export.zip.description"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "doc.zipper")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(isExporting || memories.isEmpty)
                    }

                    if isExporting {
                        divider

                        settingRow {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(exportProgress)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }

            if memories.isEmpty {
                Text(String(localized: "settings.export.noMemories"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .alert(exportAlertTitle, isPresented: $showExportAlert) {
            Button(String(localized: "common.done"), role: .cancel) {}
        } message: {
            Text(exportAlertMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = zipFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportToPhotos() {
        isExporting = true
        exportProgress = String(localized: "settings.export.inProgress")

        Task {
            do {
                let count = try await ExportService.shared.exportToPhotosAlbum(memories: memories)
                exportAlertTitle = String(localized: "settings.export.success")
                exportAlertMessage = String(localized: "settings.export.success.photos \(count)")
                showExportAlert = true
            } catch {
                exportAlertTitle = String(localized: "settings.export.error")
                exportAlertMessage = error.localizedDescription
                showExportAlert = true
            }
            isExporting = false
            exportProgress = ""
        }
    }

    private func createBackup() {
        isExporting = true
        exportProgress = String(localized: "settings.export.inProgress")

        Task {
            do {
                let url = try await ExportService.shared.createBackupArchive(memories: memories)
                zipFileURL = url
                showShareSheet = true
            } catch {
                exportAlertTitle = String(localized: "settings.export.error")
                exportAlertMessage = error.localizedDescription
                showExportAlert = true
            }
            isExporting = false
            exportProgress = ""
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "settings.language"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            GlassCard(padding: 0) {
                settingRow {
                    HStack {
                        Text(String(localized: "settings.language"))
                        Spacer()
                        Picker("", selection: $appLanguage) {
                            Text(String(localized: "settings.language.system")).tag("system")
                            Text("English").tag("en")
                            Text("한국어").tag("ko")
                        }
                        .onChange(of: appLanguage) { _, newValue in
                            if newValue == "system" {
                                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                            } else {
                                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                            }
                        }
                    }
                }
            }

            Text(String(localized: "settings.language.description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "settings.about"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    settingRow {
                        HStack {
                            Text(String(localized: "settings.about.version"))
                            Spacer()
                            Text("1.1.0")
                                .foregroundStyle(.secondary)
                        }
                    }

                    divider

                    settingRow {
                        Link(destination: URL(string: "https://glimm-landing-page.vercel.app/privacy")!) {
                            HStack {
                                Text(String(localized: "settings.about.privacy"))
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
                                Text(String(localized: "settings.about.terms"))
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
