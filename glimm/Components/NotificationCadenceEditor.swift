//
//  NotificationCadenceEditor.swift
//  glimm
//

import SwiftUI

struct NotificationCadenceEditor: View {
    @Binding var notifyStart: Date
    @Binding var notifyEnd: Date
    @Binding var cadenceMode: NotificationCadenceMode
    @Binding var intervalHours: Int
    @Binding var dailyCount: Int

    var onChange: () -> Void = {}

    @State private var showDailyCountEditor = false

    var body: some View {
        VStack(spacing: 0) {
            settingRow {
                HStack {
                    Text(String(localized: "settings.notifications.startTime"))
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { notifyStart },
                            set: { newValue in
                                notifyStart = newValue
                                onChange()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }

            divider

            settingRow {
                HStack {
                    Text(String(localized: "settings.notifications.endTime"))
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { notifyEnd },
                            set: { newValue in
                                notifyEnd = newValue
                                onChange()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }

            divider

            settingRow {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "settings.notifications.interval"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        ForEach(AppConstants.notificationIntervalPresets, id: \.self) { preset in
                            Button {
                                cadenceMode = .interval
                                intervalHours = preset
                                onChange()
                            } label: {
                                Text(String(localized: "settings.notifications.interval.option \(preset)"))
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isSelectedPreset(preset) ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelectedPreset(preset) ? Color.primary : Color.primary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(intervalSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            divider

            DisclosureGroup(
                isExpanded: Binding(
                    get: { showDailyCountEditor || cadenceMode == .customCount },
                    set: { showDailyCountEditor = $0 }
                )
            ) {
                VStack(spacing: 12) {
                    HStack {
                        Text("settings.notifications.frequency \(dailyCount)", bundle: .main)
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                if dailyCount > 1 {
                                    dailyCount -= 1
                                    cadenceMode = .customCount
                                    showDailyCountEditor = true
                                    onChange()
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 44, height: 36)
                            }

                            Divider()
                                .frame(height: 20)

                            Button {
                                if dailyCount < 10 {
                                    dailyCount += 1
                                    cadenceMode = .customCount
                                    showDailyCountEditor = true
                                    onChange()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 44, height: 36)
                            }
                        }
                        .foregroundStyle(.primary)
                        .glassEffect(cornerRadius: 10)
                    }

                    Text(String(localized: "settings.notifications.customCount.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "settings.notifications.customCount"))
                            .foregroundStyle(.primary)
                        Text(cadenceMode == .customCount
                             ? String(localized: "settings.notifications.customCount.active")
                             : String(localized: "settings.notifications.customCount.inactive"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .onAppear {
            showDailyCountEditor = cadenceMode == .customCount
        }
    }

    private var intervalSummaryText: String {
        if cadenceMode == .interval {
            return String(localized: "settings.notifications.interval.summary \(intervalHours)")
        }
        return String(localized: "settings.notifications.interval.summaryInactive")
    }

    private func isSelectedPreset(_ preset: Int) -> Bool {
        cadenceMode == .interval && intervalHours == preset
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
}
