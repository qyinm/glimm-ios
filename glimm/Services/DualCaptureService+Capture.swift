//
//  DualCaptureService+Capture.swift
//  glimm
//

import AVFoundation
import UIKit

extension DualCaptureService {
    func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        backCapturedImage = nil
        frontCapturedImage = nil

        if dualModeEnabled && DualCaptureService.isMultiCamSupported {
            captureMultiCam()
        } else if dualModeEnabled {
            captureSequential()
        } else {
            captureSingle()
        }
    }

    private func captureMultiCam() {
        guard canCapturePhoto(from: backPhotoOutput),
              canCapturePhoto(from: frontPhotoOutput) else {
            finishUnavailablePhotoConnection()
            return
        }

        let backSettings = AVCapturePhotoSettings()
        if backPhotoOutput.supportedFlashModes.contains(flashMode) {
            backSettings.flashMode = flashMode
        }

        let frontSettings = AVCapturePhotoSettings()
        frontSettings.flashMode = .off

        backPhotoOutput.capturePhoto(with: backSettings, delegate: self)
        frontPhotoOutput.capturePhoto(with: frontSettings, delegate: self)
    }

    private func captureSingle() {
        let settings = AVCapturePhotoSettings()
        let output = isSwapped ? frontPhotoOutput : backPhotoOutput

        guard canCapturePhoto(from: output) else {
            finishUnavailablePhotoConnection()
            return
        }

        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func captureSequential() {
        // Start with back camera
        let settings = AVCapturePhotoSettings()
        if backPhotoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }

        // Ensure we are on back camera configuration
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Reconfigure for back if not already
            if self.backInput == nil {
                self.session.beginConfiguration()
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }
                self.setupSingleCamSession(position: .back)
                self.session.commitConfiguration()
            }

            guard self.canCapturePhoto(from: self.backPhotoOutput) else {
                Task { @MainActor in
                    self.finishUnavailablePhotoConnection()
                }
                return
            }

            // Need a slight delay to let the session reconfigure and exposure settle if we just switched
            // But if we are already running back cam (default state), we can capture immediately
            self.backPhotoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func continueSequentialCapture() {
        // Switch to front camera and capture
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            self.setupSingleCamSession(position: .front)
            self.session.commitConfiguration()

            // Wait for ISP to settle (critical for single-session switch)
            Thread.sleep(forTimeInterval: 0.5)

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            guard self.canCapturePhoto(from: self.frontPhotoOutput) else {
                Task { @MainActor in
                    self.finishUnavailablePhotoConnection()
                }
                return
            }
            self.frontPhotoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func canCapturePhoto(from output: AVCapturePhotoOutput) -> Bool {
        guard let connection = output.connection(with: .video) else {
            return false
        }

        return connection.isActive && connection.isEnabled
    }

    private func finishUnavailablePhotoConnection() {
        backCapturedImage = nil
        frontCapturedImage = nil
        capturedImage = nil

        #if targetEnvironment(simulator)
        capturedImage = Self.simulatorPlaceholderImage()
        isCapturing = false
        #else
        isCapturing = false
        errorMessage = CaptureError.photoCaptureFailed.localizedDescription
        #endif
    }

    private func checkAndComposite() {
        guard let backImage = backCapturedImage, let frontImage = frontCapturedImage else { return }

        // Determine which is main vs PIP based on isSwapped
        let mainImage = isSwapped ? frontImage : backImage
        let pipImage = isSwapped ? backImage : frontImage

        capturedImage = compositeImages(main: mainImage, pip: pipImage)

        // Reset sequential fallback state if needed
        if !DualCaptureService.isMultiCamSupported {
            // Restore proper camera for next preview
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.session.beginConfiguration()
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }
                self.setupSingleCamSession(position: self.isSwapped ? .front : .back)
                self.session.commitConfiguration()
            }
        }

        isCapturing = false
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension DualCaptureService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            Task { @MainActor in
                self.isCapturing = false // Reset on error
                self.errorMessage = CaptureError.photoCaptureFailed.localizedDescription
            }
            return
        }

        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }

        // Handle orientation fix if needed (UIImage usually preserves it from metadata, but compositing might strip if not careful.
        // UIGraphicsImageRenderer respects UIImage orientation).

        Task { @MainActor in
            if !self.dualModeEnabled {
                // Single mode: use photo directly
                self.capturedImage = image
                self.isCapturing = false
            } else if output == self.backPhotoOutput {
                self.backCapturedImage = image

                if !DualCaptureService.isMultiCamSupported {
                    // Trigger front capture in sequence
                    self.continueSequentialCapture()
                } else {
                    self.checkAndComposite()
                }
            } else if output == self.frontPhotoOutput {
                self.frontCapturedImage = image
                self.checkAndComposite()
            }
        }
    }
}
