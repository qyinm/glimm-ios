//
//  ContentView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            checkExistingUser()
        }
    }

    // Auto-skip onboarding for existing users who already have memories
    func checkExistingUser() {
        if !hasCompletedOnboarding {
            let descriptor = FetchDescriptor<Memory>()
            if let count = try? modelContext.fetchCount(descriptor), count > 0 {
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Memory.self, Settings.self], inMemory: true)
}
