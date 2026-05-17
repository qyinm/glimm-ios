//
//  MainTabView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("reviewPromptsEnabled") private var reviewPromptsEnabled = false
    @Query(sort: \Memory.capturedAt, order: .reverse) private var memories: [Memory]

    @State private var selectedTab = MainTabItem.timeline
    @State private var showCapture = false
    @State private var selectedNotificationMemory: Memory?

    private var settings: Settings {
        Settings.getOrCreate(in: modelContext)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Content
            Group {
                switch selectedTab {
                case .timeline:
                    HomeView()
                case .review:
                    ReviewView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Tab Bar
            customTabBar
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureView()
        }
        .sheet(item: $selectedNotificationMemory) { memory in
            MemoryDetailView(memory: memory)
        }
        .mainTabNotificationCoordination(
            selectedTab: $selectedTab,
            showCapture: $showCapture,
            selectedNotificationMemory: $selectedNotificationMemory,
            settings: settings,
            reviewPromptsEnabled: reviewPromptsEnabled,
            memories: memories
        )
    }

    private var customTabBar: some View {
        HStack {
            // Regular tabs in glass container
            HStack(spacing: 0) {
                tabButton(icon: "square.stack", title: String(localized: "tab.timeline"), tag: .timeline)
                tabButton(icon: "sparkles", title: String(localized: "tab.review"), tag: .review)
                tabButton(icon: "gearshape", title: String(localized: "tab.settings"), tag: .settings)
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

    private func tabButton(icon: String, title: String, tag: MainTabItem) -> some View {
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
