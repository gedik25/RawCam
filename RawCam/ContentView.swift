//
//  ContentView.swift
//  RawCam
//
//  Created by AliGedik on 1.02.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Camera Preview
            if cameraManager.cameraPermissionGranted {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                PermissionDeniedView()
            }
            
            // Overlay UI
            VStack {
                // Top Bar: Lens Selector + RAW Status
                topBar
                
                Spacer()
                
                // Status Message
                if let status = cameraManager.lastCaptureStatus {
                    statusBadge(status)
                }
                
                // Bottom Bar: Capture Button
                bottomBar
            }
            .padding()
        }
        .onAppear {
            cameraManager.checkCameraPermission()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // RAW Status Indicator
            rawStatusIndicator
            
            Spacer()
            
            // Lens Picker
            lensPicker
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var rawStatusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(cameraManager.isRawSupported ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(cameraManager.isRawSupported ? "RAW" : "HEIC")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var lensPicker: some View {
        HStack(spacing: 4) {
            ForEach(LensType.allCases, id: \.self) { lens in
                Button {
                    cameraManager.switchLens(to: lens)
                } label: {
                    Text(lensLabel(lens))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            cameraManager.currentLens == lens
                                ? Color.white.opacity(0.3)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .foregroundColor(.white)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private func lensLabel(_ lens: LensType) -> String {
        switch lens {
        case .wide:
            return "1x"
        case .ultraWide:
            return "0.5x"
        }
    }
    
    // MARK: - Status Badge
    
    private func statusBadge(_ status: String) -> some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 16)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut, value: status)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            Spacer()
            
            // Capture Button
            captureButton
            
            Spacer()
        }
        .padding(.bottom, 30)
    }
    
    private var captureButton: some View {
        Button {
            cameraManager.capturePhoto()
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                // Inner circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(cameraManager.isCaptureInProgress ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: cameraManager.isCaptureInProgress)
            }
        }
        .disabled(cameraManager.isCaptureInProgress || !cameraManager.cameraPermissionGranted)
        .opacity(cameraManager.isCaptureInProgress ? 0.6 : 1.0)
    }
}

// MARK: - Permission Denied View

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Kamera İzni Gerekli")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("RAW fotoğraf çekebilmek için kamera erişimine izin vermeniz gerekiyor.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Ayarlara Git")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    ContentView()
}
