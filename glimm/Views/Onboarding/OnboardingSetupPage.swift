//
//  OnboardingSetupPage.swift
//  glimm
//

import SwiftUI
import AVFoundation

struct OnboardingSetupPage: View {
    @Binding var notifyStart: Date
    @Binding var notifyEnd: Date
    @Binding var notifyFrequency: Int
    @Binding var notificationCadenceMode: NotificationCadenceMode
    @Binding var notificationIntervalHours: Int

    @State private var notificationGranted = false
    @State private var cameraGranted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(String(localized: "onboarding.setup.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                // Permissions section
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding.setup.permissions"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    GlassCard(padding: 0) {
                        VStack(spacing: 0) {
                            // Notification permission
                            Button {
                                Task {
                                    notificationGranted = await NotificationService.shared.requestPermission()
                                }
                            } label: {
                                permissionRow(
                                    icon: "bell.fill",
                                    title: String(localized: "onboarding.setup.notifications"),
                                    description: String(localized: "onboarding.setup.notifications.description"),
                                    granted: notificationGranted
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 16)

                            // Camera permission
                            Button {
                                Task {
                                    cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
                                }
                            } label: {
                                permissionRow(
                                    icon: "camera.fill",
                                    title: String(localized: "onboarding.setup.camera"),
                                    description: String(localized: "onboarding.setup.camera.description"),
                                    granted: cameraGranted
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Notification schedule section
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding.setup.schedule"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    GlassCard(padding: 0) {
                        NotificationCadenceEditor(
                            notifyStart: $notifyStart,
                            notifyEnd: $notifyEnd,
                            cadenceMode: $notificationCadenceMode,
                            intervalHours: $notificationIntervalHours,
                            dailyCount: $notifyFrequency
                        )
                    }

                    Text(String(localized: "settings.notifications.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                // Bottom spacing for the start button
                Spacer()
                    .frame(height: 80)
            }
            .padding(.horizontal, 24)
        }
        .task {
            await checkCurrentPermissions()
        }
    }

    private func checkCurrentPermissions() async {
        let notifSettings = await UNUserNotificationCenter.current().notificationSettings()
        notificationGranted = notifSettings.authorizationStatus == .authorized

        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 32)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    OnboardingSetupPage(
        notifyStart: .constant(Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()),
        notifyEnd: .constant(Calendar.current.date(from: DateComponents(hour: 21)) ?? Date()),
        notifyFrequency: .constant(3),
        notificationCadenceMode: .constant(.interval),
        notificationIntervalHours: .constant(3)
    )
}
