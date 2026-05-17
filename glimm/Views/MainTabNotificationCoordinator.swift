//
//  MainTabNotificationCoordinator.swift
//  glimm
//

import SwiftUI

enum MainTabItem: Int, Equatable {
    case timeline
    case review
    case settings
}

struct MainTabNotificationRouteTarget: Equatable {
    let selectedTab: MainTabItem?
    let presentsCapture: Bool
    let selectedMemoryID: UUID?
}

enum MainTabNotificationRouter {
    static func target(
        for route: NotificationRoute,
        loadedMemoryIDs: Set<UUID>
    ) -> MainTabNotificationRouteTarget {
        switch route.destination {
        case .capture:
            return MainTabNotificationRouteTarget(
                selectedTab: nil,
                presentsCapture: true,
                selectedMemoryID: nil
            )
        case .reviewHome:
            return MainTabNotificationRouteTarget(
                selectedTab: .review,
                presentsCapture: false,
                selectedMemoryID: nil
            )
        case .memoryDetail:
            return MainTabNotificationRouteTarget(
                selectedTab: .review,
                presentsCapture: false,
                selectedMemoryID: loadedMemoryID(for: route, loadedMemoryIDs: loadedMemoryIDs)
            )
        }
    }

    private static func loadedMemoryID(
        for route: NotificationRoute,
        loadedMemoryIDs: Set<UUID>
    ) -> UUID? {
        guard let memoryID = route.memoryID,
              loadedMemoryIDs.contains(memoryID) else {
            return nil
        }

        return memoryID
    }
}

private struct MainTabNotificationCoordinator: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    @Binding var selectedTab: MainTabItem
    @Binding var showCapture: Bool
    @Binding var selectedNotificationMemory: Memory?

    let settings: Settings
    let reviewPromptsEnabled: Bool
    let memories: [Memory]

    func body(content: Content) -> some View {
        content
            .task {
                await initializeNotifications()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                Task {
                    await initializeNotifications()
                }
            }
            .onAppear(perform: routePendingLaunchDestination)
            .onReceive(NotificationCenter.default.publisher(for: .openNotificationDestination)) { notification in
                guard let notificationRoute = notification.object as? NotificationRoute else { return }

                AppDelegate.pendingLaunchRoute = nil
                route(to: notificationRoute)
            }
    }

    private func routePendingLaunchDestination() {
        guard let notificationRoute = AppDelegate.pendingLaunchRoute else { return }

        AppDelegate.pendingLaunchRoute = nil
        route(to: notificationRoute)
    }

    private func route(to route: NotificationRoute) {
        let target = MainTabNotificationRouter.target(
            for: route,
            loadedMemoryIDs: Set(memories.map(\.id))
        )

        if let selectedTab = target.selectedTab {
            self.selectedTab = selectedTab
        }

        if target.presentsCapture {
            showCapture = true
        }

        if let memoryID = target.selectedMemoryID,
           let memory = memories.first(where: { $0.id == memoryID }) {
            selectedNotificationMemory = memory
        }
    }

    private func initializeNotifications() async {
        if !reviewPromptsEnabled {
            await NotificationService.shared.cancelReviewNotifications()
        }

        guard settings.notifyEnabled || reviewPromptsEnabled else { return }

        let granted = await NotificationService.shared.requestPermission()
        guard granted else { return }

        if settings.notifyEnabled {
            await NotificationService.shared.scheduleRandomNotifications(settings: settings)
        }

        if reviewPromptsEnabled {
            let candidates = ReviewOrganizer.reviewNotificationCandidates(
                from: memories,
                reviewPromptsEnabled: reviewPromptsEnabled
            )
            await NotificationService.shared.scheduleReviewNotifications(candidates: candidates)
        }
    }
}

extension View {
    func mainTabNotificationCoordination(
        selectedTab: Binding<MainTabItem>,
        showCapture: Binding<Bool>,
        selectedNotificationMemory: Binding<Memory?>,
        settings: Settings,
        reviewPromptsEnabled: Bool,
        memories: [Memory]
    ) -> some View {
        modifier(
            MainTabNotificationCoordinator(
                selectedTab: selectedTab,
                showCapture: showCapture,
                selectedNotificationMemory: selectedNotificationMemory,
                settings: settings,
                reviewPromptsEnabled: reviewPromptsEnabled,
                memories: memories
            )
        )
    }
}
