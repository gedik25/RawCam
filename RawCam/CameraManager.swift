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
    
    // MARK: - AVFoundation Properties
    // These properties are accessed from sessionQueue, marked as nonisolated(unsafe)
    
    nonisolated(unsafe) let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.rawcam.session.queue")
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var currentDeviceInput: AVCaptureDeviceInput?
    
    // MARK: - Capture Tracking
    
    private var expectedCallbackCount = 0
    private var receivedCallbackCount = 0
    private var capturedFormats: [String] = []
    private var statusClearTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
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
            
            // Update RAW support status
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
            }
        } catch {
            print("Error creating camera input: \(error)")
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
            
            self.updateRawSupportStatus()
            
            Task { @MainActor in
                self.currentLens = lens
            }
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
                // RAW + processed HEIC - will get 2 callbacks
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
                // Fallback to processed only - will get 1 callback
                settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ])
                willCaptureRaw = false
            }
            
            Task { @MainActor in
                // RAW+HEIC = 2 callbacks, HEIC only = 1 callback
                self.expectedCallbackCount = willCaptureRaw ? 2 : 1
            }
            
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
            
            // Save to photo library
            self.savePhotoToLibrary(photo)
        }
    }
    
    private func savePhotoToLibrary(_ photo: AVCapturePhoto) {
        guard let data = photo.fileDataRepresentation() else {
            handleCaptureResult(success: false, format: nil, error: "Fotoğraf verisi alınamadı")
            return
        }
        
        // Check if this is a RAW photo
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
        
        // Check if all callbacks received
        if receivedCallbackCount >= expectedCallbackCount {
            isCaptureInProgress = false
            
            if let error = error, capturedFormats.isEmpty {
                lastCaptureStatus = "Hata: \(error)"
            } else if capturedFormats.isEmpty {
                lastCaptureStatus = "Kayıt başarısız"
            } else {
                // Show combined status
                let formatString = capturedFormats.joined(separator: " + ")
                lastCaptureStatus = "\(formatString) kaydedildi"
            }
            
            // Auto-clear status after 3 seconds
            scheduleStatusClear()
        }
    }
}
