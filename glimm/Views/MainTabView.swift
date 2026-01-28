//
//  MainTabView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCapture = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Timeline", systemImage: "square.stack")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)

            Color.clear
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                showCapture = true
                selectedTab = oldValue
            }
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureView()
        }
        .tint(.black)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Memory.self, Settings.self], inMemory: true)
}
