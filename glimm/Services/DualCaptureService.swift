//
//  DualCaptureService.swift
//  glimm
//
//  Created by Antigravity on 2026-01-28.
//

import AVFoundation
import UIKit
import Combine
import SwiftUI

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
    
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    
    private var mainCameraDevice: AVCaptureDevice? {
        isSwapped ? frontInput?.device : backInput?.device
    }
    private let backPhotoOutput = AVCapturePhotoOutput()
    private let frontPhotoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "app.glimm.camera.session")
    
    // MARK: - Capture State
    private var backCapturedImage: UIImage?
    private var frontCapturedImage: UIImage?
    
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
    
    // MARK: - Public Methods
    
    func startSession() {
        guard !isSessionRunning else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                Task { @MainActor in
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        guard isSessionRunning else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                Task { @MainActor in
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupSession()
        }
    }
    
    func reconfigureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.setupSession()
            self.session.startRunning()
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }
    
    func switchCameras() {
        isSwapped.toggle()
        if !dualModeEnabled || !DualCaptureService.isMultiCamSupported {
            reconfigureSession()
        } else {
            connectPreviewLayersIfReady()
        }
    }
    
    func toggleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }
    
    func requestCameraAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAccessGranted = granted
        return granted
    }
    
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
    
    // MARK: - Private Setup Methods
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAccessGranted = true
        case .notDetermined:
            Task {
                await requestCameraAccess()
            }
        default:
            cameraAccessGranted = false
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Remove existing inputs/outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        backInput = nil
        frontInput = nil
        
        if dualModeEnabled && DualCaptureService.isMultiCamSupported {
            setupMultiCamSession()
        } else {
            setupSingleCamSession(position: isSwapped ? .front : .back)
        }
        
        connectPreviewLayers()
    }
    
    private func setupMultiCamSession() {
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            Task { @MainActor in
                self.errorMessage = CaptureError.cameraUnavailable.localizedDescription
            }
            return
        }
        
        do {
            let backInput = try AVCaptureDeviceInput(device: backCamera)
            let frontInput = try AVCaptureDeviceInput(device: frontCamera)
            
            if session.canAddInput(backInput) {
                session.addInputWithNoConnections(backInput)
                self.backInput = backInput
            }
            
            if session.canAddInput(frontInput) {
                session.addInputWithNoConnections(frontInput)
                self.frontInput = frontInput
            }
            
            if session.canAddOutput(backPhotoOutput) {
                session.addOutputWithNoConnections(backPhotoOutput)
            }
            
            if session.canAddOutput(frontPhotoOutput) {
                session.addOutputWithNoConnections(frontPhotoOutput)
            }
            
            // Connect Back Camera
            if let backPort = backInput.ports(for: .video, sourceDeviceType: backCamera.deviceType, sourceDevicePosition: backCamera.position).first {
                let backConnection = AVCaptureConnection(inputPorts: [backPort], output: backPhotoOutput)
                if session.canAddConnection(backConnection) {
                    session.addConnection(backConnection)
                }
            }
            
            // Connect Front Camera
            if let frontPort = frontInput.ports(for: .video, sourceDeviceType: frontCamera.deviceType, sourceDevicePosition: frontCamera.position).first {
                let frontConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontPhotoOutput)
                frontConnection.automaticallyAdjustsVideoMirroring = false
                frontConnection.isVideoMirrored = true // Mirror front camera
                if session.canAddConnection(frontConnection) {
                    session.addConnection(frontConnection)
                }
            }
            
        } catch {
            Task { @MainActor in
                self.errorMessage = CaptureError.sessionConfigFailed.localizedDescription
            }
        }
    }
    
    private func setupSingleCamSession(position: AVCaptureDevice.Position) {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInputWithNoConnections(input)
                if position == .back {
                    self.backInput = input
                } else {
                    self.frontInput = input
                }
            }
            
            let output = position == .back ? backPhotoOutput : frontPhotoOutput
            if session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
            }
            
            if let port = input.ports(for: .video, sourceDeviceType: camera.deviceType, sourceDevicePosition: position).first {
                let connection = AVCaptureConnection(inputPorts: [port], output: output)
                if position == .front {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                }
                if session.canAddConnection(connection) {
                    session.addConnection(connection)
                }
            }
        } catch {
            Task { @MainActor in
                self.errorMessage = CaptureError.sessionConfigFailed.localizedDescription
            }
        }
    }
    
    private func connectPreviewLayersIfReady() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.connectPreviewLayers()
            self.session.commitConfiguration()
        }
    }
    
    private func connectPreviewLayers() {
        let mainPort: AVCaptureInput.Port?
        let pipPort: AVCaptureInput.Port?
        
        if dualModeEnabled && DualCaptureService.isMultiCamSupported {
            mainPort = isSwapped ? frontVideoPort : backVideoPort
            pipPort = isSwapped ? backVideoPort : frontVideoPort
        } else {
            mainPort = backVideoPort ?? frontVideoPort
            pipPort = nil
        }

        if let mainLayer = mainPreviewLayer, let oldConn = mainLayer.connection {
            session.removeConnection(oldConn)
        }
        if let pipLayer = pipPreviewLayer, let oldConn = pipLayer.connection {
            session.removeConnection(oldConn)
        }
        
        if let mainLayer = mainPreviewLayer, let port = mainPort {
            let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: mainLayer)
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = port.sourceDevicePosition == .front
            conn.videoOrientation = .portrait
            if session.canAddConnection(conn) { session.addConnection(conn) }
        }
        if let pipLayer = pipPreviewLayer, let port = pipPort {
            let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: pipLayer)
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = port.sourceDevicePosition == .front
            conn.videoOrientation = .portrait
            if session.canAddConnection(conn) { session.addConnection(conn) }
        }
    }
    
    // MARK: - Capture Logic
    
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

    #if targetEnvironment(simulator)
    private static func simulatorPlaceholderImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let text = "glimm simulator camera"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attributes)
        }
    }
    #endif

    // MARK: - Image Processing
    
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
    
    func compositeImages(main: UIImage, pip: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: main.size)
        return renderer.image { ctx in
            // Draw main image full size
            main.draw(in: CGRect(origin: .zero, size: main.size))
            
            // Calculate PIP size and position (top-right, ~30% width)
            let pipWidth = main.size.width * 0.3
            let pipHeight = pipWidth * (pip.size.height / pip.size.width)
            let margin: CGFloat = 16 * (main.size.width / 390) // Scale margin relative
            let pipRect = CGRect(
                x: main.size.width - pipWidth - margin,
                y: margin,
                width: pipWidth,
                height: pipHeight
            )
            
            let cornerRadius: CGFloat = 16 * (main.size.width / 390)
            
            ctx.cgContext.saveGState()
            let clipPath = UIBezierPath(roundedRect: pipRect, cornerRadius: cornerRadius)
            clipPath.addClip()
            pip.draw(in: pipRect)
            ctx.cgContext.restoreGState()
        }
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

// MARK: - Errors
enum CaptureError: LocalizedError {
    case sessionConfigFailed
    case cameraUnavailable
    case photoCaptureFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionConfigFailed: return "Failed to configure camera session"
        case .cameraUnavailable: return "Camera is not available"
        case .photoCaptureFailed: return "Failed to capture photo"
        }
    }
}
