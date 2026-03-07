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

                    HStack(spacing: 8) {
                        Text("\(memory.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if memory.audioData != nil {
                            Label(
                                (memory.audioDuration ?? 0).formattedAsAudioDuration,
                                systemImage: "waveform"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

private extension TimeInterval {
    var formattedAsAudioDuration: String {
        let totalSeconds = Int(self.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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
