//
//  CameraPreview.swift
//  RawCam
//
//  Created by AliGedik on 1.02.2026.
//

import AVFoundation
import SwiftUI

// MARK: - Preview UIView

final class PreviewUIView: UIView {
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    func setSession(_ session: AVCaptureSession) {
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - SwiftUI Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.setSession(session)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.setSession(session)
    }
}

#Preview {
    CameraPreview(session: AVCaptureSession())
        .ignoresSafeArea()
}
