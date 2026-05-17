//
//  AudioNoteDraftController.swift
//  glimm
//

import AVFoundation
import Combine
import Foundation

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
