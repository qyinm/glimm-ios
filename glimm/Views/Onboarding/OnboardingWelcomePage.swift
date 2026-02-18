//
//  OnboardingWelcomePage.swift
//  glimm
//

import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

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
