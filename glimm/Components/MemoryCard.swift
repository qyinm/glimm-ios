//
//  MemoryCard.swift
//  glimm
//

import SwiftUI

struct MemoryCard: View {
    let memory: Memory

    var body: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageData = memory.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Color.clear
                        .frame(height: 200)
                        .overlay {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let note = memory.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }

                    Text("\(memory.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
    }
}

#Preview {
    let memory = Memory(
        imageData: nil,
        note: "Coffee with an old friend",
        capturedAt: .now
    )

    return MemoryCard(memory: memory)
        .padding()
}
