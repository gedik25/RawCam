//
//  CameraManager.swift
//  RawCam
//
//  Created by AliGedik on 1.02.2026.
//

import AVFoundation
import Photos
import SwiftUI
import Observation
import CoreMedia
import UIKit

// MARK: - Lens Type

enum LensType: String, CaseIterable, Sendable {
    case wide = "Wide"
    case ultraWide = "Ultra Wide"
    
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .wide:
            return .builtInWideAngleCamera
        case .ultraWide:
            return .builtInUltraWideCamera
        }
    }
}

// MARK: - Camera Preset

enum CameraPreset: String, CaseIterable, Sendable {
    case auto = "Auto"
    case portrait = "Portrait"
    case night = "Night"
    case action = "Action"
    case landscape = "Landscape"
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .auto: return "a.circle"
        case .portrait: return "person.fill"
        case .night: return "moon.fill"
        case .action: return "figure.run"
        case .landscape: return "mountain.2.fill"
        }
    }
}

// MARK: - Exposure Mode

enum ExposureMode: String, CaseIterable, Sendable {
    case auto = "Auto"
    case manual = "Manual"
}

// MARK: - Focus Mode

enum FocusMode: String, CaseIterable, Sendable {
    case auto = "Auto"
    case manual = "Manual"
}

// MARK: - Camera Manager

@Observable
@MainActor
final class CameraManager: NSObject {
    
    // MARK: - Observable Properties
    
    var isSessionRunning = false
    var currentLens: LensType = .wide
    var isRawSupported = false
    var isCaptureInProgress = false
    var lastCaptureStatus: String?
    var cameraPermissionGranted = false
    
    // MARK: - Exposure Properties
    
    var exposureMode: ExposureMode = .auto
    nonisolated(unsafe) var currentISO: Float = 100
    var minISO: Float = 50
    var maxISO: Float = 3200
    nonisolated(unsafe) var currentShutterSpeed: Double = 1.0 / 60.0 // seconds
    var minShutterSpeed: Double = 1.0 / 8000.0
    var maxShutterSpeed: Double = 1.0
    
    // MARK: - Focus Properties
    
    var focusMode: FocusMode = .auto
    nonisolated(unsafe) var currentFocusDistance: Float = 0.5 // 0.0 (near) to 1.0 (infinity)
    var focusPointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    // MARK: - Preset Properties
    
    var currentPreset: CameraPreset = .auto
    
    // MARK: - Thumbnail
    
    var lastCapturedThumbnail: UIImage?
    
    // MARK: - Orientation Properties
    
    nonisolated(unsafe) private var currentVideoOrientation: AVCaptureVideoOrientation = .portrait
    nonisolated(unsafe) private var lastValidOrientation: AVCaptureVideoOrientation = .portrait
    
    // MARK: - AVFoundation Properties
    
    nonisolated(unsafe) let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.rawcam.session.queue")
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var currentDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var currentDevice: AVCaptureDevice?
    
    // MARK: - Capture Tracking
    
    private var expectedCallbackCount = 0
    private var receivedCallbackCount = 0
    private var capturedFormats: [String] = []
    private var statusClearTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupOrientationObserver()
    }
    
    private func setupOrientationObserver() {
        // Start generating device orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Set initial orientation
        updateCurrentOrientation()
        
        // Observe orientation changes via NotificationCenter
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCurrentOrientation()
        }
    }
    
    private func updateCurrentOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        
        // Map UIDeviceOrientation to AVCaptureVideoOrientation
        // Note: Landscape requires cross-mapping due to sensor inversion
        let videoOrientation: AVCaptureVideoOrientation?
        
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            // Cross-mapping: device landscapeLeft -> video landscapeRight
            videoOrientation = .landscapeRight
        case .landscapeRight:
            // Cross-mapping: device landscapeRight -> video landscapeLeft
            videoOrientation = .landscapeLeft
        case .faceUp, .faceDown, .unknown:
            // Use fallback for invalid orientations
            videoOrientation = nil
        @unknown default:
            videoOrientation = nil
        }
        
        // Update current orientation or use fallback
        if let orientation = videoOrientation {
            currentVideoOrientation = orientation
            lastValidOrientation = orientation
        }
        // If nil, currentVideoOrientation keeps the lastValidOrientation value
    }
    
    /// Returns the video rotation angle for the current orientation
    private nonisolated func currentVideoRotationAngle() -> CGFloat {
        switch currentVideoOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeRight:
            return 0
        case .landscapeLeft:
            return 180
        @unknown default:
            return 90
        }
    }
    
    /// Forces orientation sync before capture
    private nonisolated func syncOrientationForCapture() {
        guard let connection = photoOutput.connection(with: .video) else { return }
        
        // Use lastValidOrientation as fallback if current is invalid
        let orientationToUse = currentVideoOrientation
        
        // Set video orientation on connection
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = orientationToUse
        }
        
        // Also set rotation angle for iOS 17+
        let rotationAngle = currentVideoRotationAngle()
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    // MARK: - Permission
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraPermissionGranted = granted
                    if granted {
                        self?.configureSession()
                    }
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }
    
    // MARK: - Session Configuration
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Add input for current lens
            self.setupCameraInput(for: self.currentLens)
            
            // Add photo output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            
            // Update device capabilities
            self.updateDeviceCapabilities()
            self.updateRawSupportStatus()
        }
    }
    
    private nonisolated func setupCameraInput(for lens: LensType) {
        // Remove existing input
        if let existingInput = currentDeviceInput {
            session.removeInput(existingInput)
        }
        
        // Get camera device
        guard let device = AVCaptureDevice.default(lens.deviceType, for: .video, position: .back) else {
            print("Camera device not available: \(lens.rawValue)")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                currentDeviceInput = input
                currentDevice = device
            }
        } catch {
            print("Error creating camera input: \(error)")
        }
    }
    
    private nonisolated func updateDeviceCapabilities() {
        guard let device = currentDevice else { return }
        
        let minIso = device.activeFormat.minISO
        let maxIso = device.activeFormat.maxISO
        let minDuration = device.activeFormat.minExposureDuration
        let maxDuration = device.activeFormat.maxExposureDuration
        
        Task { @MainActor in
            self.minISO = minIso
            self.maxISO = maxIso
            self.minShutterSpeed = CMTimeGetSeconds(minDuration)
            self.maxShutterSpeed = CMTimeGetSeconds(maxDuration)
            
            // Clamp current values to valid range
            self.currentISO = min(max(self.currentISO, minIso), maxIso)
        }
    }
    
    private nonisolated func updateRawSupportStatus() {
        let rawSupported = !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
        Task { @MainActor in
            self.isRawSupported = rawSupported
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
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
    
    // MARK: - Lens Switching
    
    func switchLens(to lens: LensType) {
        guard lens != currentLens else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.setupCameraInput(for: lens)
            self.session.commitConfiguration()
            
            self.updateDeviceCapabilities()
            self.updateRawSupportStatus()
            
            Task { @MainActor in
                self.currentLens = lens
            }
        }
    }
    
    // MARK: - Exposure Control
    
    func setExposureMode(_ mode: ExposureMode) {
        exposureMode = mode
        
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                
                if mode == .auto {
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                } else {
                    // Apply current manual settings
                    self.applyManualExposure()
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Error setting exposure mode: \(error)")
            }
        }
    }
    
    func setISO(_ iso: Float) {
        let clampedISO = min(max(iso, minISO), maxISO)
        currentISO = clampedISO
        
        if exposureMode == .manual {
            applyManualExposureAsync()
        }
    }
    
    func setShutterSpeed(_ speed: Double) {
        let clampedSpeed = min(max(speed, minShutterSpeed), maxShutterSpeed)
        currentShutterSpeed = clampedSpeed
        
        if exposureMode == .manual {
            applyManualExposureAsync()
        }
    }
    
    private func applyManualExposureAsync() {
        sessionQueue.async { [weak self] in
            self?.applyManualExposure()
        }
    }
    
    private nonisolated func applyManualExposure() {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isExposureModeSupported(.custom) {
                let duration = CMTimeMakeWithSeconds(currentShutterSpeed, preferredTimescale: 1000000)
                device.setExposureModeCustom(duration: duration, iso: currentISO) { _ in }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error applying manual exposure: \(error)")
        }
    }
    
    // MARK: - Focus Control
    
    func setFocusMode(_ mode: FocusMode) {
        focusMode = mode
        
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                
                if mode == .auto {
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                } else {
                    self.applyManualFocus()
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Error setting focus mode: \(error)")
            }
        }
    }
    
    func setFocusDistance(_ distance: Float) {
        let clampedDistance = min(max(distance, 0.0), 1.0)
        currentFocusDistance = clampedDistance
        
        if focusMode == .manual {
            applyManualFocusAsync()
        }
    }
    
    func focusAt(point: CGPoint) {
        focusPointOfInterest = point
        
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            
            guard device.isFocusPointOfInterestSupported else { return }
            
            do {
                try device.lockForConfiguration()
                
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                
                // Also set exposure point if supported
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                
                device.unlockForConfiguration()
                
                Task { @MainActor in
                    self.focusMode = .auto
                    self.exposureMode = .auto
                }
            } catch {
                print("Error focusing at point: \(error)")
            }
        }
    }
    
    private func applyManualFocusAsync() {
        sessionQueue.async { [weak self] in
            self?.applyManualFocus()
        }
    }
    
    private nonisolated func applyManualFocus() {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.locked) {
                device.setFocusModeLocked(lensPosition: currentFocusDistance) { _ in }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error applying manual focus: \(error)")
        }
    }
    
    // MARK: - Preset Control
    
    func applyPreset(_ preset: CameraPreset) {
        currentPreset = preset
        
        switch preset {
        case .auto:
            setExposureMode(.auto)
            setFocusMode(.auto)
            
        case .portrait:
            setExposureMode(.manual)
            setISO(100)
            setShutterSpeed(1.0 / 60.0)
            setFocusMode(.auto)
            
        case .night:
            setExposureMode(.manual)
            setISO(1600)
            setShutterSpeed(1.0 / 15.0)
            setFocusMode(.auto)
            
        case .action:
            setExposureMode(.manual)
            setISO(400)
            setShutterSpeed(1.0 / 1000.0)
            setFocusMode(.auto)
            
        case .landscape:
            setExposureMode(.manual)
            setISO(100)
            setShutterSpeed(1.0 / 125.0)
            setFocusDistance(1.0) // Focus at infinity
            setFocusMode(.manual)
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        guard !isCaptureInProgress else { return }
        
        isCaptureInProgress = true
        lastCaptureStatus = nil
        receivedCallbackCount = 0
        capturedFormats = []
        
        // Cancel any pending status clear
        statusClearTask?.cancel()
        statusClearTask = nil
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings: AVCapturePhotoSettings
            let willCaptureRaw: Bool
            
            // Check if RAW is supported for current lens
            if let rawFormat = self.photoOutput.availableRawPhotoPixelFormatTypes.first,
               let rawFileType = self.photoOutput.availableRawPhotoFileTypes.first {
                // RAW + processed HEIC
                let processedFormat: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ]
                
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawFormat,
                    rawFileType: rawFileType,
                    processedFormat: processedFormat,
                    processedFileType: .heic
                )
                willCaptureRaw = true
            } else {
                // Fallback to processed only
                settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ])
                willCaptureRaw = false
            }
            
            Task { @MainActor in
                self.expectedCallbackCount = willCaptureRaw ? 2 : 1
            }
            
            // Force orientation sync before capture
            self.syncOrientationForCapture()
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Status Management
    
    private func scheduleStatusClear() {
        statusClearTask?.cancel()
        statusClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                self.lastCaptureStatus = nil
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func formatShutterSpeed(_ speed: Double) -> String {
        if speed >= 1.0 {
            return String(format: "%.1fs", speed)
        } else {
            let denominator = Int(round(1.0 / speed))
            return "1/\(denominator)"
        }
    }
    
    func formatISO(_ iso: Float) -> String {
        return "ISO \(Int(iso))"
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                self.lastCaptureStatus = "Hata: \(error.localizedDescription)"
                self.isCaptureInProgress = false
                self.scheduleStatusClear()
                return
            }
            
            // Generate thumbnail from processed photo (not RAW)
            if !photo.isRawPhoto {
                if let cgImage = photo.cgImageRepresentation() {
                    let thumbnail = UIImage(cgImage: cgImage)
                    self.lastCapturedThumbnail = thumbnail
                }
            }
            
            // Save to photo library
            self.savePhotoToLibrary(photo)
        }
    }
    
    private func savePhotoToLibrary(_ photo: AVCapturePhoto) {
        guard let data = photo.fileDataRepresentation() else {
            handleCaptureResult(success: false, format: nil, error: "Fotoğraf verisi alınamadı")
            return
        }
        
        let isRaw = photo.isRawPhoto
        let format = isRaw ? "RAW" : "HEIC"
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized else {
                Task { @MainActor in
                    self?.handleCaptureResult(success: false, format: nil, error: "Galeri izni gerekli")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                let options = PHAssetResourceCreationOptions()
                if isRaw {
                    options.uniformTypeIdentifier = "com.adobe.raw-image"
                }
                
                creationRequest.addResource(
                    with: .photo,
                    data: data,
                    options: options
                )
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        self?.handleCaptureResult(success: true, format: format, error: nil)
                    } else if let error = error {
                        self?.handleCaptureResult(success: false, format: nil, error: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func handleCaptureResult(success: Bool, format: String?, error: String?) {
        receivedCallbackCount += 1
        
        if let format = format, success {
            capturedFormats.append(format)
        }
        
        if receivedCallbackCount >= expectedCallbackCount {
            isCaptureInProgress = false
            
            if let error = error, capturedFormats.isEmpty {
                lastCaptureStatus = "Hata: \(error)"
            } else if capturedFormats.isEmpty {
                lastCaptureStatus = "Kayıt başarısız"
            } else {
                let formatString = capturedFormats.joined(separator: " + ")
                lastCaptureStatus = "\(formatString) kaydedildi"
            }
            
            scheduleStatusClear()
        }
    }
}
