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
    @Environment(\.modelContext) private var modelContext
    @StateObject private var service = DualCaptureService()
    
    @State private var isDualMode: Bool = false
    @State private var baseZoomFactor: CGFloat = 1.0
    @State private var showZoomIndicatorState: Bool = false
    @State private var zoomIndicatorWorkItem: DispatchWorkItem?
    @State private var mainPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var pipPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var switchRotation: Double = 0
    
    var onImageCaptured: (UIImage) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Camera Preview
            CameraPreviewView(
                session: service.session,
                showPIP: isDualMode && DualCaptureService.isMultiCamSupported,
                previewLayer: $mainPreviewLayer,
                pipLayer: $pipPreviewLayer
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
                        service.focus(at: value.location, in: previewLayer)
                    }
            )
            
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
                    .opacity((!isDualMode && service.isSwapped) ? 0.0 : 1.0)
                    .disabled(!isDualMode && service.isSwapped)
                    
                    if DualCaptureService.isMultiCamSupported {
                        Button {
                            toggleDualMode()
                        } label: {
                            Image(systemName: isDualMode ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(isDualMode ? .yellow : .white)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
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
                
                ZStack {
                    // Center Capture Button
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
                    
                    // Right Switch Button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                switchRotation += 180
                            }
                            service.switchCameras()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(switchRotation))
                        }
                        .disabled(service.isCapturing)
                        .padding(.trailing, 40)
                    }
                }
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
                FocusRingView(position: focusPoint)
            }
        }
        .onAppear {
            isDualMode = Settings.getOrCreate(in: modelContext).dualCaptureEnabled
            service.dualModeEnabled = isDualMode
            service.configureSession()
            service.startSession()
        }
        .onDisappear {
            service.stopSession()
        }
        .onChange(of: mainPreviewLayer) { _, layer in
            service.mainPreviewLayer = layer
        }
        .onChange(of: pipPreviewLayer) { _, layer in
            service.pipPreviewLayer = layer
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
    private func toggleDualMode() {
        isDualMode.toggle()
        service.dualModeEnabled = isDualMode
        Settings.getOrCreate(in: modelContext).dualCaptureEnabled = isDualMode
        service.reconfigureSession()
    }
    
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


