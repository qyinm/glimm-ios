//
//  OnboardingPrivateArchivePage.swift
//  glimm
//

import SwiftUI

struct OnboardingPrivateArchivePage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.primary)

            Text(String(localized: "onboarding.private.title"))
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                privacyPoint(
                    icon: "iphone",
                    text: String(localized: "onboarding.private.point1")
                )

                privacyPoint(
                    icon: "icloud",
                    text: String(localized: "onboarding.private.point2")
                )

                privacyPoint(
                    icon: "eye.slash",
                    text: String(localized: "onboarding.private.point3")
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 32)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    OnboardingPrivateArchivePage()
}
