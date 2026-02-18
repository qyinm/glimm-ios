//
//  OnboardingHowItWorksPage.swift
//  glimm
//

import SwiftUI

struct OnboardingHowItWorksPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(String(localized: "onboarding.howItWorks.title"))
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 20) {
                stepRow(
                    icon: "bell.fill",
                    title: String(localized: "onboarding.howItWorks.step1.title"),
                    description: String(localized: "onboarding.howItWorks.step1.description")
                )

                stepRow(
                    icon: "camera.fill",
                    title: String(localized: "onboarding.howItWorks.step2.title"),
                    description: String(localized: "onboarding.howItWorks.step2.description")
                )

                stepRow(
                    icon: "square.stack.fill",
                    title: String(localized: "onboarding.howItWorks.step3.title"),
                    description: String(localized: "onboarding.howItWorks.step3.description")
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func stepRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingHowItWorksPage()
}
