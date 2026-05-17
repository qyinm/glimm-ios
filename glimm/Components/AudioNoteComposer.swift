//
//  AudioNoteComposer.swift
//  glimm
//

import SwiftUI
import UIKit

struct AudioNoteComposer: View {
    @Binding var audioData: Data?
    @Binding var audioDuration: Double?
    @Binding var isRecording: Bool

    @StateObject private var controller = AudioNoteDraftController()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if controller.permissionDenied {
                Text(String(localized: "capture.audio.permissionDenied"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(String(localized: "capture.audio.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.subheadline)
            }

            if controller.recordedData == nil {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "capture.audio.title"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "capture.audio.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            await controller.toggleRecording()
                        }
                    } label: {
                        Label(
                            controller.isRecording
                                ? String(localized: "capture.audio.stop")
                                : String(localized: "capture.audio.record"),
                            systemImage: controller.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(controller.isRecording ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(controller.isRecording ? Color.red : Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if controller.isRecording {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text(controller.recordingDuration.formattedAsAudioDuration)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let recordedData = controller.recordedData {
                AudioNotePlaybackView(
                    audioData: recordedData,
                    audioDuration: controller.recordedDuration
                )

                HStack {
                    Button {
                        controller.clear()
                    } label: {
                        Label(String(localized: "capture.audio.delete"), systemImage: "trash")
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Button {
                        controller.clear()
                        Task {
                            await controller.toggleRecording()
                        }
                    } label: {
                        Label(String(localized: "capture.audio.rerecord"), systemImage: "arrow.clockwise")
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(16)
        .glassEffect(cornerRadius: 16)
        .onAppear {
            controller.load(recordedData: audioData, duration: audioDuration)
            isRecording = controller.isRecording
        }
        .onChange(of: controller.recordedData) { _, newValue in
            audioData = newValue
        }
        .onChange(of: controller.recordedDuration) { _, newValue in
            audioDuration = newValue
        }
        .onChange(of: controller.isRecording) { _, newValue in
            isRecording = newValue
        }
        .onDisappear {
            isRecording = false
        }
    }
}

struct AudioNotePlaybackView: View {
    let audioData: Data
    let audioDuration: Double?
    var title: String = String(localized: "capture.audio.saved")
    var accentColor: Color = .primary
    var controlForegroundColor: Color = .white
    var textColor: Color = .primary
    var secondaryTextColor: Color = .secondary

    @StateObject private var player = AudioNotePlayerController()

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.togglePlayback(audioData: audioData)
            } label: {
                Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(controlForegroundColor)
                    .frame(width: 40, height: 40)
                    .background(accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
                Text((audioDuration ?? player.lastKnownDuration).formattedAsAudioDuration)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .monospacedDigit()
            }

            Spacer()
        }
        .onDisappear {
            player.stop()
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
