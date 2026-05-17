//
//  DualCaptureService+Controls.swift
//  glimm
//

import AVFoundation
import UIKit

extension DualCaptureService {
    func setZoom(_ factor: CGFloat) {
        guard let device = mainCameraDevice else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            let clamped = max(device.minAvailableVideoZoomFactor,
                              min(factor, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = clamped
            currentZoomFactor = clamped
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }

    func focus(at point: CGPoint, in previewLayer: AVCaptureVideoPreviewLayer) {
        guard let device = mainCameraDevice else { return }

        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }

            focusPoint = point
            exposureBias = 0.0
            isAdjustingFocus = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.focusPoint = nil
                self?.isAdjustingFocus = false
            }
        } catch {
            print("Failed to set focus: \(error)")
        }
    }

    func setExposureBias(_ bias: Float) {
        guard let device = mainCameraDevice else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            let clamped = max(device.minExposureTargetBias,
                              min(bias, device.maxExposureTargetBias))
            device.setExposureTargetBias(clamped) { _ in }
            exposureBias = clamped
        } catch {
            print("Failed to set exposure: \(error)")
        }
    }
}
