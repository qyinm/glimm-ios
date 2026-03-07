//
//  AudioNoteComposer.swift
//  glimm
//

import SwiftUI
import AVFoundation
import Combine
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

@MainActor
final class AudioNoteDraftController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedData: Data?
    @Published var recordedDuration: Double?
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStopTask: Task<Void, Never>?
    private var recordingProgressTask: Task<Void, Never>?

    func load(recordedData: Data?, duration: Double?) {
        guard self.recordedData == nil else { return }
        self.recordedData = recordedData
        recordedDuration = duration
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }

    func clear() {
        stopRecording()
        recordedData = nil
        recordedDuration = nil
        recordingDuration = 0
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        self.recordingURL = nil
    }

    func startRecording() async {
        guard await requestPermissionIfNeeded() else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            recordingURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            recorder.record()

            self.recorder = recorder
            isRecording = true
            recordingDuration = 0
            scheduleAutoStop()
            startTimer()
        } catch {
            permissionDenied = true
        }
    }

    func stopRecording() {
        finishRecording()
    }

    private func requestPermissionIfNeeded() async -> Bool {
        let permission = AVAudioApplication.shared.recordPermission

        switch permission {
        case .granted:
            permissionDenied = false
            return true
        case .denied:
            permissionDenied = true
            return false
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            permissionDenied = !granted
            return granted
        @unknown default:
            permissionDenied = true
            return false
        }
    }

    private func startTimer() {
        stopTimer()
        recordingProgressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self,
                      self.isRecording,
                      let recorder = self.recorder else { continue }

                self.recordingDuration = min(recorder.currentTime, AppConstants.maxAudioNoteDuration)
            }
        }
    }

    private func stopTimer() {
        recordingProgressTask?.cancel()
        recordingProgressTask = nil
    }

    private func scheduleAutoStop() {
        recordingStopTask?.cancel()
        recordingStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AppConstants.maxAudioNoteDuration))
            guard let self, self.isRecording else { return }
            self.finishRecording()
        }
    }

    private func finishRecording() {
        recordingStopTask?.cancel()
        recordingStopTask = nil

        guard let recorder else {
            isRecording = false
            stopTimer()
            return
        }

        let finalDuration = min(recorder.currentTime, AppConstants.maxAudioNoteDuration)
        recorder.stop()
        self.recorder = nil
        isRecording = false
        stopTimer()

        if let data = try? Data(contentsOf: recorder.url) {
            recordedData = data
            recordedDuration = finalDuration
            recordingDuration = finalDuration
        }
    }
}

@MainActor
final class AudioNotePlayerController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false

    var lastKnownDuration: Double = 0

    private var player: AVAudioPlayer?

    func togglePlayback(audioData: Data) {
        if isPlaying {
            stop()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            player.prepareToPlay()
            player.play()

            lastKnownDuration = player.duration
            self.player = player
            isPlaying = true
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
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
