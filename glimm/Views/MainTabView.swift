//
//  MainTabView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [Settings]

    @State private var selectedTab = 0
    @State private var showCapture = false

    private var settings: Settings {
        if let existing = allSettings.first {
            return existing
        }
        let newSettings = Settings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Content
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    CalendarView()
                case 2:
                    SettingsView()
                default:
                    HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Tab Bar
            customTabBar
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureView()
        }
        .task {
            await initializeNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await initializeNotifications()
                }
            }
        }
        .onAppear {
            // Check flag for cold launch (app was terminated when notification tapped)
            if AppDelegate.shouldOpenCamera {
                AppDelegate.shouldOpenCamera = false
                showCapture = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCamera)) { _ in
            showCapture = true
        }
    }

    private func initializeNotifications() async {
        guard settings.notifyEnabled else { return }

        let granted = await NotificationService.shared.requestPermission()
        if granted {
            await NotificationService.shared.scheduleRandomNotifications(settings: settings)
        }
    }

    private var customTabBar: some View {
        HStack {
            // Regular tabs in glass container
            HStack(spacing: 0) {
                tabButton(icon: "square.stack", title: String(localized: "tab.timeline"), tag: 0)
                tabButton(icon: "calendar", title: String(localized: "tab.calendar"), tag: 1)
                tabButton(icon: "gearshape", title: String(localized: "tab.settings"), tag: 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                liquidGlassBackground
            }
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)

            Spacer()

            // Standalone Capture button - separate from tab container
            Button {
                showCapture = true
            } label: {
                ZStack {
                    // Liquid glass background (same as tab bar)
                    Circle()
                        .fill(.ultraThinMaterial)
                    
                    // Inner highlight
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    
                    // Subtle border
                    Circle()
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 68, height: 68)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var liquidGlassBackground: some View {
        ZStack {
            // Base blur - fully round
            Capsule()
                .fill(.ultraThinMaterial)

            // Inner highlight (top edge)
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // Subtle border
            Capsule()
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .symbolVariant(selectedTab == tag ? .fill : .none)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.caption2)
                    .fontWeight(selectedTab == tag ? .medium : .regular)
            }
            .foregroundStyle(selectedTab == tag ? .primary : .secondary)
            .frame(width: 72, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Memory.self, Settings.self], inMemory: true)
}
