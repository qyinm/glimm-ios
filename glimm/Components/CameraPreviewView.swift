//
//  CameraPreviewView.swift
//  glimm
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var showPIP: Bool = false
    @Binding var previewLayer: AVCaptureVideoPreviewLayer?
    @Binding var pipLayer: AVCaptureVideoPreviewLayer?

    class PreviewUIView: UIView {
        var mainLayer: AVCaptureVideoPreviewLayer?
        var pipLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            mainLayer?.frame = bounds
            if let pip = pipLayer, !pip.isHidden {
                let pipWidth: CGFloat = 120
                let pipHeight: CGFloat = 160
                let margin: CGFloat = 16
                pip.frame = CGRect(
                    x: bounds.width - pipWidth - margin,
                    y: safeAreaInsets.top + 60,
                    width: pipWidth,
                    height: pipHeight
                )
                pip.cornerRadius = 16
                pip.masksToBounds = true
            }
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black

        let mainLayer = AVCaptureVideoPreviewLayer()
        mainLayer.videoGravity = .resizeAspectFill
        mainLayer.setSessionWithNoConnection(session)
        view.layer.addSublayer(mainLayer)
        view.mainLayer = mainLayer
        DispatchQueue.main.async { previewLayer = mainLayer }

        let pip = AVCaptureVideoPreviewLayer()
        pip.videoGravity = .resizeAspectFill
        pip.setSessionWithNoConnection(session)
        pip.isHidden = true
        view.layer.addSublayer(pip)
        view.pipLayer = pip
        DispatchQueue.main.async { pipLayer = pip }

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.pipLayer?.isHidden = !showPIP
        uiView.setNeedsLayout()
    }
}

#Preview {
    CameraPreviewView(
        session: AVCaptureSession(),
        previewLayer: .constant(nil),
        pipLayer: .constant(nil)
    )
}
