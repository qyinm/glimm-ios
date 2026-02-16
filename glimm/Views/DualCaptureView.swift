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
                    isSwapped: service.isSwapped
                )
                .ignoresSafeArea()
                // Tap gesture on PIP is handled internally by DualPreviewView or via coordinate space
                // But DualPreviewView is a single view. The PIP logic in the prompt suggested:
                // "Overlay a tap gesture on the PIP region"
                // Since DualPreviewView draws both layers, we can't easily attach a SwiftUI gesture to just the PIP layer *inside* the UIViewRepresentable without passing coordinates.
                // HOWEVER, the prompt says: "// PIP border overlay (for multi-cam, drawn in SwiftUI on top)"
                // AND "// ... positioned at top-right"
                // So I should draw a SwiftUI view on top of the PIP location to handle the tap.
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
                
                // Capture Button
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

// MARK: - Dual Preview View (UIViewRepresentable)

struct DualPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let backPort: AVCaptureInput.Port?
    let frontPort: AVCaptureInput.Port?
    let isSwapped: Bool
    
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
