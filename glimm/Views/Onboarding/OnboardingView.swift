//
//  OnboardingView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    @State private var currentPage = 0
    @State private var notifyStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var notifyEnd = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    @State private var notifyFrequency = 3

    private let totalPages = 4

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingWelcomePage()
                        .tag(0)

                    OnboardingHowItWorksPage()
                        .tag(1)

                    OnboardingPrivateArchivePage()
                        .tag(2)

                    OnboardingSetupPage(
                        notifyStart: $notifyStart,
                        notifyEnd: $notifyEnd,
                        notifyFrequency: $notifyFrequency
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }

            if currentPage < totalPages - 1 {
                // Skip + Next buttons
                HStack {
                    Button {
                        withAnimation {
                            currentPage = totalPages - 1
                        }
                    } label: {
                        Text(String(localized: "onboarding.skip"))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text(String(localized: "onboarding.next"))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            } else {
                // Start button
                Button {
                    completeOnboarding()
                } label: {
                    Text(String(localized: "onboarding.start"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func completeOnboarding() {
        // Save settings
        let settings = Settings.getOrCreate(in: modelContext)
        settings.notifyStart = notifyStart
        settings.notifyEnd = notifyEnd
        settings.notifyFrequency = notifyFrequency
        settings.notifyEnabled = true

        // Schedule notifications
        Task {
            await NotificationService.shared.scheduleRandomNotifications(settings: settings)
        }

        // Mark onboarding as completed
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Memory.self, Settings.self], inMemory: true)
}
