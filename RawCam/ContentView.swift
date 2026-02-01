//
//  ContentView.swift
//  RawCam
//
//  Created by AliGedik on 1.02.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var cameraManager = CameraManager()
    @State private var histogramGenerator = HistogramGenerator()
    @State private var showControls = true
    @State private var showHistogram = true
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // Camera Preview
                if cameraManager.cameraPermissionGranted {
                    CameraPreview(session: cameraManager.session)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            handleTapToFocus(at: location, in: geometry.size)
                        }
                } else {
                    PermissionDeniedView()
                }
                
                // Overlay UI - Different layout for landscape/portrait
                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .onAppear {
            cameraManager.checkCameraPermission()
            cameraManager.startSession()
            histogramGenerator.setupVideoOutput(for: cameraManager.session)
            histogramGenerator.enable()
        }
        .onDisappear {
            cameraManager.stopSession()
            histogramGenerator.disable()
        }
    }
    
    // MARK: - Portrait Layout
    
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Histogram (top left)
            if showHistogram {
                HStack {
                    HistogramView(data: histogramGenerator.histogramData)
                        .frame(width: 120, height: 60)
                        .padding(8)
                    Spacer()
                }
            }
            
            Spacer()
            
            // Status Message
            if let status = cameraManager.lastCaptureStatus {
                statusBadge(status)
            }
            
                // Control Panel or Toggle Button
                if showControls {
                    controlPanel
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                } else {
                    // Show toggle button when panel is hidden
                    Button {
                        withAnimation { showControls = true }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Kontroller")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                    }
                    .padding(.bottom, 8)
                }
                
                // Bottom Bar
                bottomBar
                    .padding(.horizontal)
                    .padding(.bottom, 30)
        }
    }
    
    // MARK: - Landscape Layout
    
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left side: Preview area with overlays
            VStack(spacing: 0) {
                // Top Bar (compact for landscape)
                landscapeTopBar
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                
                Spacer()
                
                // Status Message
                if let status = cameraManager.lastCaptureStatus {
                    statusBadge(status)
                        .padding(.bottom, 8)
                }
                
                // Bottom: Thumbnail only (left side)
                HStack {
                    thumbnailButton
                    Spacer()
                    
                    // Controls toggle when panel is hidden
                    if !showControls {
                        Button {
                            withAnimation { showControls = true }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            
            // Right side: Control Panel + Capture button (rightmost)
            HStack(spacing: 0) {
                // Control Panel (if visible)
                if showControls {
                    landscapeControlPanel
                        .frame(width: min(geometry.size.width * 0.28, 220))
                }
                
                // Capture button - vertically centered on far right edge
                VStack {
                    Spacer()
                    captureButton
                    Spacer()
                }
                .frame(width: 90)
                .padding(.vertical, 8)
            }
            .padding(.trailing, 8)
        }
    }
    
    // MARK: - Landscape Top Bar
    
    private var landscapeTopBar: some View {
        HStack(spacing: 8) {
            // RAW Status
            rawStatusIndicator
            
            // Lens Picker
            lensPicker
            
            Spacer()
            
            // Histogram (inline for landscape)
            if showHistogram {
                HistogramView(data: histogramGenerator.histogramData)
                    .frame(width: 100, height: 50)
            }
            
            // Histogram Toggle
            Button {
                withAnimation { showHistogram.toggle() }
            } label: {
                Image(systemName: showHistogram ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            // Preset Picker
            presetPicker
        }
    }
    
    // MARK: - Landscape Control Panel (Side Panel)
    
    private var landscapeControlPanel: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(cameraManager.exposureMode == .auto ? "AUTO" : "MANUAL")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    withAnimation { showControls = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(4)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // ISO
            compactSlider(
                label: "ISO",
                value: Binding(
                    get: { Double(cameraManager.currentISO) },
                    set: { cameraManager.setISO(Float($0)) }
                ),
                range: Double(cameraManager.minISO)...Double(cameraManager.maxISO),
                displayValue: "\(Int(cameraManager.currentISO))",
                isManual: cameraManager.exposureMode == .manual
            )
            
            // Shutter Speed
            compactSlider(
                label: "SS",
                value: $cameraManager.currentShutterSpeed,
                range: cameraManager.minShutterSpeed...cameraManager.maxShutterSpeed,
                displayValue: cameraManager.formatShutterSpeed(cameraManager.currentShutterSpeed),
                isManual: cameraManager.exposureMode == .manual,
                onChanged: { cameraManager.setShutterSpeed($0) }
            )
            
            // Focus
            compactSlider(
                label: "Focus",
                value: Binding(
                    get: { Double(cameraManager.currentFocusDistance) },
                    set: { cameraManager.currentFocusDistance = Float($0) }
                ),
                range: 0...1,
                displayValue: cameraManager.focusMode == .manual ? String(format: "%.1f", cameraManager.currentFocusDistance) : "A",
                isManual: cameraManager.focusMode == .manual,
                onChanged: { if cameraManager.focusMode == .manual { cameraManager.setFocusDistance(Float($0)) } }
            )
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Mode Toggles (Vertical for landscape)
            VStack(spacing: 8) {
                landscapeModeButton(
                    title: "Exposure",
                    isManual: cameraManager.exposureMode == .manual
                ) {
                    let newMode: ExposureMode = cameraManager.exposureMode == .auto ? .manual : .auto
                    cameraManager.setExposureMode(newMode)
                }
                
                landscapeModeButton(
                    title: "Focus",
                    isManual: cameraManager.focusMode == .manual
                ) {
                    let newMode: FocusMode = cameraManager.focusMode == .auto ? .manual : .auto
                    cameraManager.setFocusMode(newMode)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 8)
        .padding(.trailing, 8)
    }
    
    private func compactSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayValue: String,
        isManual: Bool,
        onChanged: ((Double) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(displayValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isManual ? .yellow : .white.opacity(0.7))
            }
            
            Slider(value: value, in: range)
                .tint(isManual ? .yellow : .white.opacity(0.5))
                .disabled(!isManual)
                .onChange(of: value.wrappedValue) { _, newValue in
                    onChanged?(newValue)
                }
        }
    }
    
    private func landscapeModeButton(title: String, isManual: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isManual ? "m.circle.fill" : "a.circle.fill")
                    .foregroundColor(isManual ? .yellow : .white.opacity(0.7))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Text(isManual ? "Manual" : "Auto")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isManual ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Tap to Focus
    
    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(
            x: location.x / size.width,
            y: location.y / size.height
        )
        cameraManager.focusAt(point: normalizedPoint)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // RAW Status
            rawStatusIndicator
            
            // Lens Picker
            lensPicker
            
            Spacer()
            
            // Histogram Toggle
            Button {
                withAnimation { showHistogram.toggle() }
            } label: {
                Image(systemName: showHistogram ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            // Preset Picker
            presetPicker
        }
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
    
    private var presetPicker: some View {
        Menu {
            ForEach(CameraPreset.allCases, id: \.self) { preset in
                Button {
                    cameraManager.applyPreset(preset)
                } label: {
                    Label(preset.displayName, systemImage: preset.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: cameraManager.currentPreset.icon)
                Text(cameraManager.currentPreset.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .foregroundColor(.white)
        }
    }
    
    private func lensLabel(_ lens: LensType) -> String {
        switch lens {
        case .wide: return "1x"
        case .ultraWide: return "0.5x"
        }
    }
    
    // MARK: - Control Panel (Portrait)
    
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Toggle Controls Button
            HStack {
                Button {
                    withAnimation { showControls.toggle() }
                } label: {
                    Image(systemName: showControls ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                Spacer()
                Text(cameraManager.exposureMode == .auto ? "AUTO" : "MANUAL")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // ISO Slider
            exposureSlider(
                label: "ISO",
                value: Binding(
                    get: { Double(cameraManager.currentISO) },
                    set: { cameraManager.setISO(Float($0)) }
                ),
                range: Double(cameraManager.minISO)...Double(cameraManager.maxISO),
                displayValue: cameraManager.formatISO(cameraManager.currentISO),
                isManual: cameraManager.exposureMode == .manual
            )
            
            // Shutter Speed Slider
            exposureSlider(
                label: "SS",
                value: $cameraManager.currentShutterSpeed,
                range: cameraManager.minShutterSpeed...cameraManager.maxShutterSpeed,
                displayValue: cameraManager.formatShutterSpeed(cameraManager.currentShutterSpeed),
                isManual: cameraManager.exposureMode == .manual,
                onChanged: { cameraManager.setShutterSpeed($0) }
            )
            
            // Focus Slider
            focusSlider
            
            // Mode Toggles
            modeToggles
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func exposureSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayValue: String,
        isManual: Bool,
        onChanged: ((Double) -> Void)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30, alignment: .leading)
            
            Slider(value: value, in: range)
                .tint(isManual ? .yellow : .white.opacity(0.5))
                .disabled(!isManual)
                .onChange(of: value.wrappedValue) { _, newValue in
                    onChanged?(newValue)
                }
            
            Text(displayValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 60, alignment: .trailing)
        }
    }
    
    private var focusSlider: some View {
        HStack(spacing: 8) {
            Text("Focus")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 40, alignment: .leading)
            
            Slider(
                value: $cameraManager.currentFocusDistance,
                in: 0...1
            )
            .tint(cameraManager.focusMode == .manual ? .yellow : .white.opacity(0.5))
            .disabled(cameraManager.focusMode != .manual)
            .onChange(of: cameraManager.currentFocusDistance) { _, newValue in
                if cameraManager.focusMode == .manual {
                    cameraManager.setFocusDistance(newValue)
                }
            }
            
            Text(cameraManager.focusMode == .manual ? String(format: "%.2f", cameraManager.currentFocusDistance) : "Auto")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private var modeToggles: some View {
        HStack(spacing: 16) {
            // Exposure Mode Toggle
            Button {
                let newMode: ExposureMode = cameraManager.exposureMode == .auto ? .manual : .auto
                cameraManager.setExposureMode(newMode)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: cameraManager.exposureMode == .auto ? "a.circle" : "m.circle")
                    Text("Exposure")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(cameraManager.exposureMode == .manual ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1))
                .clipShape(Capsule())
                .foregroundColor(.white)
            }
            
            // Focus Mode Toggle
            Button {
                let newMode: FocusMode = cameraManager.focusMode == .auto ? .manual : .auto
                cameraManager.setFocusMode(newMode)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: cameraManager.focusMode == .auto ? "a.circle" : "m.circle")
                    Text("Focus")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(cameraManager.focusMode == .manual ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1))
                .clipShape(Capsule())
                .foregroundColor(.white)
            }
            
            Spacer()
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
            .padding(.bottom, 8)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            // Thumbnail
            thumbnailButton
            
            Spacer()
            
            // Capture Button
            captureButton
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 50, height: 50)
        }
    }
    
    private var thumbnailButton: some View {
        Button {
            openPhotosApp()
        } label: {
            Group {
                if let thumbnail = cameraManager.lastCapturedThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            }
        }
        .disabled(cameraManager.lastCapturedThumbnail == nil)
    }
    
    private func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
    
    private var captureButton: some View {
        Button {
            cameraManager.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
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
