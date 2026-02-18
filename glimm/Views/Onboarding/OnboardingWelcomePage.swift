//
//  OnboardingWelcomePage.swift
//  glimm
//

import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.primary)

            Text("glimm")
                .font(.system(size: 48, weight: .bold, design: .default))

            Text(String(localized: "onboarding.welcome.tagline"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingWelcomePage()
}
