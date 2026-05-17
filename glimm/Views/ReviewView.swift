//
//  ReviewView.swift
//  glimm
//

import SwiftUI
import SwiftData

private enum ReviewTab: String, CaseIterable, Identifiable {
    case highlights
    case places
    case map

    var id: String { rawValue }
}

struct ReviewView: View {
    private let tabContentSpacing: CGFloat = 18

    @Query(sort: \Memory.capturedAt, order: .reverse) private var memories: [Memory]

    @State private var selectedTab: ReviewTab = .highlights
    @State private var selectedCluster: PlaceClusterSelection?
    @State private var selectedMemory: Memory?
    @State private var selectedPlace: PlaceMemoryGroup?
    @State private var showCalendar = false
    @State private var selectedDate: Date?

    private var displayMemories: [Memory] {
        guard let selectedDate else {
            return memories
        }

        let calendar = Calendar.current
        return memories.filter { memory in
            calendar.isDate(memory.capturedAt, inSameDayAs: selectedDate)
        }
    }

    private var reviewHome: ReviewHome {
        ReviewOrganizer.reviewHome(from: displayMemories)
    }

    private var placeGroups: [PlaceMemoryGroup] {
        ReviewOrganizer.placeGroups(from: displayMemories)
    }

    private var highlightSections: [ReviewSection] {
        ReviewSectionReason.reviewHomeDisplayOrder.flatMap { reason in
            reviewHome.sections.filter { $0.reason == reason }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .background(Color(.systemBackground))
            .sheet(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory)
            }
            .sheet(item: $selectedCluster) { selection in
                PlaceClusterSheetView(selection: selection)
            }
            .sheet(item: $selectedPlace) { place in
                PlaceReviewDetailView(place: place)
            }
            .sheet(isPresented: $showCalendar) {
                CalendarView { date in
                    selectedDate = date
                    showCalendar = false
                }
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: tabContentSpacing) {
            Picker("Review", selection: $selectedTab) {
                Text(String(localized: "review.tab.highlights")).tag(ReviewTab.highlights)
                Text(String(localized: "review.tab.places")).tag(ReviewTab.places)
                Text(String(localized: "review.tab.map")).tag(ReviewTab.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let selectedDate {
                selectedDateHeader(for: selectedDate)
            }

            switch selectedTab {
            case .highlights:
                highlightsView
            case .places:
                placesView
            case .map:
                mapView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(String(localized: "review.empty.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "review.empty.subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var highlightsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(highlightSections.enumerated()), id: \.offset) { _, section in
                    reviewSectionView(section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, DesignSystem.Spacing.tabBarBottom)
        }
    }

    @ViewBuilder
    private func reviewSectionView(_ section: ReviewSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(section.reason.localizedSectionTitle)

            if section.reason == .frequentPlaces {
                ForEach(section.placeGroups) { place in
                    Button {
                        selectedPlace = place
                    } label: {
                        PlaceGroupCard(place: place)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(section.memories) { memory in
                    Button {
                        selectedMemory = memory
                    } label: {
                        MemoryCard(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var placesView: some View {
        ScrollView {
            VStack(spacing: 14) {
                if placeGroups.isEmpty {
                    placesEmptyState
                } else {
                    ForEach(placeGroups) { place in
                        Button {
                            selectedPlace = place
                        } label: {
                            PlaceGroupCard(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, DesignSystem.Spacing.tabBarBottom)
        }
    }

    private var placesEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(String(localized: "review.places.empty"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var mapView: some View {
        ZStack {
            if placeGroups.isEmpty {
                placesEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ClusteredPlacesMapView(
                    places: placeGroups,
                    selectedPlace: $selectedPlace
                ) { places in
                    selectedCluster = PlaceClusterSelection(places: places)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedDateHeader(for date: Date) -> some View {
        HStack {
            Text(date, format: .dateTime.month().day().weekday(.wide))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

private struct PlaceClusterSelection: Identifiable {
    let places: [PlaceMemoryGroup]

    var id: String {
        places.map(\.id).sorted().joined(separator: "|")
    }
}

private extension ReviewSectionReason {
    static let reviewHomeDisplayOrder: [ReviewSectionReason] = [
        .hero,
        .onThisDay,
        .fallbackMemory,
        .recentWeek,
        .voiceMemories,
        .locationMemories,
        .frequentPlaces,
    ]

    var localizedSectionTitle: String {
        switch self {
        case .hero:
            String(localized: "review.section.hero")
        case .onThisDay:
            String(localized: "review.section.onThisDay")
        case .fallbackMemory:
            String(localized: "review.section.fallbackMemory")
        case .recentWeek:
            String(localized: "review.section.recentWeek")
        case .voiceMemories:
            String(localized: "review.section.voiceMemories")
        case .locationMemories:
            String(localized: "review.section.locationMemories")
        case .frequentPlaces:
            String(localized: "review.section.frequentPlaces")
        }
    }
}

private struct PlaceGroupCard: View {
    let place: PlaceMemoryGroup

    var body: some View {
        GlassCard(padding: 0) {
            HStack(spacing: 14) {
                thumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(String(localized: "review.places.count \(place.memories.count)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "review.places.lastVisited \(place.lastVisitedAt.formatted(date: .abbreviated, time: .omitted))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageData = place.latestMemory.imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct PlaceClusterSheetView: View {
    let selection: PlaceClusterSelection

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(selection.places) { place in
                        NavigationLink {
                            MemoryCollectionContentView(memories: place.memories)
                                .navigationTitle(place.name)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            PlaceGroupCard(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .navigationTitle(String(localized: "review.tab.places"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "calendar.done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PlaceReviewDetailView: View {
    let place: PlaceMemoryGroup

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MemoryCollectionContentView(memories: place.memories)
                .navigationTitle(place.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "calendar.done")) {
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct MemoryCollectionContentView: View {
    let memories: [Memory]

    @State private var selectedMemory: Memory?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(memories) { memory in
                    Button {
                        selectedMemory = memory
                    } label: {
                        MemoryCard(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .sheet(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
        }
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: Memory.self, inMemory: true)
}
