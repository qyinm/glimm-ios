//
//  DualCaptureService+Session.swift
//  glimm
//

import AVFoundation

extension DualCaptureService {
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

    func checkPermission() {
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

    func setupSession() {
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

    func setupSingleCamSession(position: AVCaptureDevice.Position) {
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

    func connectPreviewLayersIfReady() {
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
}
