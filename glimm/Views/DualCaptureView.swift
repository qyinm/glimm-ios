//
//  DualCaptureView.swift
//  glimm
//
//  Created by Antigravity on 2026-02-16.
//

import SwiftUI
import AVFoundation
import UIKit

struct DualCaptureView: View {
    @StateObject private var service = DualCaptureService()
    
    // State for zoom and focus
    @State private var baseZoomFactor: CGFloat = 1.0
    @State private var showZoomIndicatorState: Bool = false
    @State private var zoomIndicatorWorkItem: DispatchWorkItem?
    @State private var mainPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var switchRotation: Double = 0
    
    var onImageCaptured: (UIImage) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Camera Preview
            if DualCaptureService.isMultiCamSupported {
                DualPreviewView(
                    session: service.session,
                    backPort: service.backVideoPort,
                    frontPort: service.frontVideoPort,
                    isSwapped: service.isSwapped,
                    mainPreviewLayer: $mainPreviewLayer
                )
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard !service.isCapturing else { return }
                            service.setZoom(baseZoomFactor * value)
                            showZoomIndicator()
                        }
                        .onEnded { value in
                            baseZoomFactor = service.currentZoomFactor
                        }
                )
                .simultaneousGesture(
                    SpatialTapGesture(coordinateSpace: .local)
                        .onEnded { value in
                            guard !service.isCapturing,
                                  let previewLayer = mainPreviewLayer else { return }
                            
                            // PIP 영역 체크 (우측 상단 120x160 영역)
                            let pipRect = CGRect(
                                x: UIScreen.main.bounds.width - 120 - 16,
                                y: UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47 + 60,
                                width: 120, height: 160
                            )
                            guard !pipRect.contains(value.location) else { return }
                            
                            service.focus(at: value.location, in: previewLayer)
                        }
                )
            } else {
                CameraPreviewView(session: service.session)
                    .ignoresSafeArea()
            }
            
            // PIP Tap Area (Ghost view for interaction)
            // We need to match the frame defined in DualPreviewView.
            // "x: bounds.width - pipWidth - margin, y: margin + 60"
            // This is tricky to match exactly in SwiftUI without GeometryReader.
            // Let's use a GeometryReader to position the SwiftUI overlay exactly where the PIP layer is.
            if DualCaptureService.isMultiCamSupported {
                GeometryReader { geometry in
                    let pipWidth: CGFloat = 120
                    let pipHeight: CGFloat = 160
                    let margin: CGFloat = 16
                    let topOffset: CGFloat = geometry.safeAreaInsets.top + 60
                    
                    // The prompt's updateUIView logic uses uiView.bounds.
                    // If we ignoreSafeArea, bounds = screen size.
                    
                    ZStack {
                        // Invisible tappable area matching PIP frame
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: pipWidth, height: pipHeight)
                            .position(
                                x: geometry.size.width - pipWidth / 2 - margin,
                                y: topOffset + pipHeight / 2
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    service.switchCameras()
                                }
                            }
                        
                        // PIP border is drawn by the CALayer in DualPreviewView (borderColor/borderWidth)
                    }
                }
                .ignoresSafeArea() // Important to match the preview layer's coordinate space
            }
            
            // Controls Overlay
            VStack {
                // Top Bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        service.toggleFlash()
                    } label: {
                        Image(systemName: flashIconName)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(service.flashMode == .off ? .white : .yellow)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Zoom Indicator
                if showZoomIndicatorState {
                    Text(String(format: "%.1fx", service.currentZoomFactor))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))
                        .padding(.bottom, 20)
                }
                
                HStack {
                    Color.clear
                        .frame(width: 60, height: 60)
                    
                    Spacer()
                    
                    Button {
                        service.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(service.isCapturing)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            switchRotation += 180
                        }
                        service.switchCameras()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .rotationEffect(.degrees(switchRotation))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            
            // Capturing Loading State
            if service.isCapturing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
            
            // Access Denied View
            if !service.cameraAccessGranted {
                cameraAccessDeniedView
            }
            
            // Focus Ring Overlay
            if let focusPoint = service.focusPoint {
                FocusRingView(
                    position: focusPoint,
                    exposureBias: service.exposureBias,
                    minExposure: service.minExposureBias,
                    maxExposure: service.maxExposureBias,
                    onExposureChange: { bias in
                        service.setExposureBias(bias)
                    }
                )
            }
        }
        .onAppear {
            service.configureSession()
            service.startSession()
        }
        .onDisappear {
            service.stopSession()
        }
        .onChange(of: service.capturedImage) { _, newImage in
            if let image = newImage {
                onImageCaptured(image)
            }
        }
    }
    
    private var flashIconName: String {
        switch service.flashMode {
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
    
    private var cameraAccessDeniedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("Please enable camera access in Settings to capture memories.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button))
            }
            .padding(40)
        }
    }
}

extension DualCaptureView {
    private func showZoomIndicator() {
        zoomIndicatorWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showZoomIndicatorState = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showZoomIndicatorState = false
            }
        }
        zoomIndicatorWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
}

// MARK: - Dual Preview View (UIViewRepresentable)

struct DualPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let backPort: AVCaptureInput.Port?
    let frontPort: AVCaptureInput.Port?
    let isSwapped: Bool
    @Binding var mainPreviewLayer: AVCaptureVideoPreviewLayer?
    
    class DualPreviewUIView: UIView {
        var mainPreviewLayer: AVCaptureVideoPreviewLayer?
        var pipPreviewLayer: AVCaptureVideoPreviewLayer?
        
        override func layoutSubviews() {
            super.layoutSubviews()
            // We handle layout in updateUIView to access SwiftUI state, 
            // but we could also do it here if we pass the params.
            // For simplicity, we'll let updateUIView drive the frames or rely on the representable to trigger updates.
            // Actually, best practice is to set frames here if they depend on bounds, 
            // but the prompt put logic in updateUIView.
            // However, the prompt's updateUIView logic sets frames directly.
        }
    }
    
    func makeUIView(context: Context) -> DualPreviewUIView {
        let view = DualPreviewUIView()
        view.backgroundColor = .black
        
        // Main preview layer (fullscreen)
        let mainLayer = AVCaptureVideoPreviewLayer()
        mainLayer.videoGravity = .resizeAspectFill
        mainLayer.setSessionWithNoConnection(session)
        view.layer.addSublayer(mainLayer)
        view.mainPreviewLayer = mainLayer
        
        DispatchQueue.main.async {
            self.mainPreviewLayer = mainLayer
        }
        
        // PIP preview layer
        let pipLayer = AVCaptureVideoPreviewLayer()
        pipLayer.videoGravity = .resizeAspectFill
        pipLayer.setSessionWithNoConnection(session)
        view.layer.addSublayer(pipLayer)
        view.pipPreviewLayer = pipLayer
        
        // Initial Connection
        connectPorts(mainLayer: mainLayer, pipLayer: pipLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: DualPreviewUIView, context: Context) {
        // Layout
        let bounds = uiView.bounds
        if bounds.isEmpty { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        uiView.mainPreviewLayer?.frame = bounds
        
        // PIP: top-right corner
        let pipWidth: CGFloat = 120
        let pipHeight: CGFloat = 160
        let margin: CGFloat = 16
        // NOTE: bounds.width might be 0 initially.
        
        uiView.pipPreviewLayer?.frame = CGRect(
            x: bounds.width - pipWidth - margin,
            y: uiView.safeAreaInsets.top + 60,
            width: pipWidth,
            height: pipHeight
        )
        uiView.pipPreviewLayer?.cornerRadius = 16
        uiView.pipPreviewLayer?.masksToBounds = true
        
        CATransaction.commit()
        
        // Update connections if swapped state changed
        if let mainLayer = uiView.mainPreviewLayer, let pipLayer = uiView.pipPreviewLayer {
            // Check if we need to reconnect (e.g. if ports changed or swap changed)
            // AVCaptureConnection objects are immutable regarding input ports.
            // So we need to remove old connections and add new ones if inputs differ.
            
            refreshConnections(session: session, mainLayer: mainLayer, pipLayer: pipLayer)
        }
    }
    
    private func connectPorts(mainLayer: AVCaptureVideoPreviewLayer, pipLayer: AVCaptureVideoPreviewLayer) {
        refreshConnections(session: session, mainLayer: mainLayer, pipLayer: pipLayer)
    }
    
    private func refreshConnections(session: AVCaptureSession, mainLayer: AVCaptureVideoPreviewLayer, pipLayer: AVCaptureVideoPreviewLayer) {
        // We need to manage connections carefully. 
        // AVCaptureMultiCamSession supports multiple connections.
        
        let newMainPort = isSwapped ? frontPort : backPort
        let newPipPort = isSwapped ? backPort : frontPort
        
        // Helper to get current input port for a layer connection
        func currentPort(for layer: AVCaptureVideoPreviewLayer) -> AVCaptureInput.Port? {
            return layer.connection?.inputPorts.first
        }
        
        // Update Main Layer
        if currentPort(for: mainLayer) != newMainPort {
            if let oldConn = mainLayer.connection {
                session.removeConnection(oldConn)
            }
            if let port = newMainPort {
                let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: mainLayer)
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = (port == frontPort) // Mirror if front
                conn.videoOrientation = .portrait // Force portrait
                if session.canAddConnection(conn) {
                    session.addConnection(conn)
                }
            }
        }
        
        // Update PIP Layer
        if currentPort(for: pipLayer) != newPipPort {
            if let oldConn = pipLayer.connection {
                session.removeConnection(oldConn)
            }
            if let port = newPipPort {
                let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: pipLayer)
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = (port == frontPort) // Mirror if front
                conn.videoOrientation = .portrait
                if session.canAddConnection(conn) {
                    session.addConnection(conn)
                }
            }
        }
    }
}
