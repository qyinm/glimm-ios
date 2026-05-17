//
//  AudioNotePlayerController.swift
//  glimm
//

import AVFoundation
import Combine
import Foundation

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
