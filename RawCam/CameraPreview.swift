//
//  CameraPreview.swift
//  RawCam
//
//  Created by AliGedik on 1.02.2026.
//

import AVFoundation
import SwiftUI
import UIKit

// MARK: - Preview UIView

final class PreviewUIView: UIView {
    
    private var orientationObserver: NSObjectProtocol?
    private var lastValidOrientation: AVCaptureVideoOrientation = .portrait
    
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
    
    func startOrientationObserving() {
        // Start generating orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Set initial orientation
        updateOrientation()
        
        // Observe orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOrientation()
        }
    }
    
    func stopOrientationObserving() {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    private func updateOrientation() {
        guard let connection = videoPreviewLayer.connection else { return }
        
        let deviceOrientation = UIDevice.current.orientation
        
        // Map UIDeviceOrientation to rotation angle
        // Note: Landscape requires cross-mapping due to sensor inversion
        let rotationAngle: CGFloat?
        
        switch deviceOrientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            // Cross-mapping: device landscapeLeft -> 0 degrees
            rotationAngle = 0
        case .landscapeRight:
            // Cross-mapping: device landscapeRight -> 180 degrees
            rotationAngle = 180
        case .faceUp, .faceDown, .unknown:
            // Use fallback for invalid orientations
            rotationAngle = nil
        @unknown default:
            rotationAngle = nil
        }
        
        // Get the angle to use (current or keep previous)
        guard let angle = rotationAngle else { return }
        
        // Only use videoRotationAngle (iOS 17+), don't mix with videoOrientation
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
    
    deinit {
        stopOrientationObserving()
    }
}

// MARK: - SwiftUI Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.setSession(session)
        view.backgroundColor = .black
        view.startOrientationObserving()
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.setSession(session)
    }
    
    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: ()) {
        uiView.stopOrientationObserving()
    }
}

#Preview {
    CameraPreview(session: AVCaptureSession())
        .ignoresSafeArea()
}
