//
//  DualCaptureService.swift
//  glimm
//
//  Created by Antigravity on 2026-01-28.
//

import AVFoundation
import Combine
import UIKit

@MainActor
class DualCaptureService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var capturedImage: UIImage?        // Composited result
    @Published var isSessionRunning: Bool = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isSwapped: Bool = false         // main/PIP camera swap state
    @Published var isCapturing: Bool = false        // capture in progress
    @Published var cameraAccessGranted: Bool = false
    @Published var errorMessage: String?
    var dualModeEnabled: Bool = true
    var mainPreviewLayer: AVCaptureVideoPreviewLayer? {
        didSet { connectPreviewLayersIfReady() }
    }
    var pipPreviewLayer: AVCaptureVideoPreviewLayer? {
        didSet { connectPreviewLayersIfReady() }
    }
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var focusPoint: CGPoint? = nil
    @Published var isAdjustingFocus: Bool = false
    @Published var exposureBias: Float = 0.0

    // MARK: - Exposure Limits
    var minExposureBias: Float {
        mainCameraDevice?.minExposureTargetBias ?? -8.0
    }

    var maxExposureBias: Float {
        mainCameraDevice?.maxExposureTargetBias ?? 8.0
    }

    // MARK: - Static
    static var isMultiCamSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    // MARK: - Session Properties
    let session: AVCaptureSession

    /// Input ports for manual preview layer connections (multi-cam only)
    var backVideoPort: AVCaptureInput.Port? {
        backInput?.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .back).first
    }

    var frontVideoPort: AVCaptureInput.Port? {
        frontInput?.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .front).first
    }

    var backInput: AVCaptureDeviceInput?
    var frontInput: AVCaptureDeviceInput?

    var mainCameraDevice: AVCaptureDevice? {
        isSwapped ? frontInput?.device : backInput?.device
    }

    let backPhotoOutput = AVCapturePhotoOutput()
    let frontPhotoOutput = AVCapturePhotoOutput()
    let sessionQueue = DispatchQueue(label: "app.glimm.camera.session")

    // MARK: - Capture State
    var backCapturedImage: UIImage?
    var frontCapturedImage: UIImage?

    // MARK: - Init
    override init() {
        if AVCaptureMultiCamSession.isMultiCamSupported {
            self.session = AVCaptureMultiCamSession()
        } else {
            self.session = AVCaptureSession()
        }
        super.init()

        checkPermission()
    }
}
