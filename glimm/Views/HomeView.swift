//
//  HomeView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memory.capturedAt, order: .reverse) private var memories: [Memory]
    @State private var selectedMemory: Memory?

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    emptyStateView
                } else {
                    memoryListView
                }
            }
            .navigationTitle("glimm")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No memories yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the camera tab to capture\nyour first moment")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var memoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedMemories, id: \.key) { date, dayMemories in
                    Section {
                        ForEach(dayMemories) { memory in
                            MemoryCard(memory: memory)
                                .onTapGesture {
                                    selectedMemory = memory
                                }
                        }
                    } header: {
                        dateHeader(for: date)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func dateHeader(for date: Date) -> some View {
        HStack {
            Text(date, format: .dateTime.month().day().weekday(.wide))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var groupedMemories: [(key: Date, value: [Memory])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: memories) { memory in
            calendar.startOfDay(for: memory.capturedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Memory.self, inMemory: true)
}
