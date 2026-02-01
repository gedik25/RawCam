//
//  HistogramView.swift
//  RawCam
//
//  Created by AliGedik on 2.02.2026.
//

import SwiftUI
import CoreImage
import AVFoundation
import Accelerate

// MARK: - Histogram Data

struct HistogramData: Sendable {
    let red: [Float]
    let green: [Float]
    let blue: [Float]
    
    static let empty = HistogramData(
        red: Array(repeating: 0, count: 256),
        green: Array(repeating: 0, count: 256),
        blue: Array(repeating: 0, count: 256)
    )
    
    var isEmpty: Bool {
        red.allSatisfy { $0 == 0 } && green.allSatisfy { $0 == 0 } && blue.allSatisfy { $0 == 0 }
    }
}

// MARK: - Histogram View

struct HistogramView: View {
    let data: HistogramData
    var height: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
                
                if !data.isEmpty {
                    // Draw RGB histograms
                    Canvas { context, size in
                        drawHistogram(context: context, size: size, data: data.red, color: .red.opacity(0.6))
                        drawHistogram(context: context, size: size, data: data.green, color: .green.opacity(0.6))
                        drawHistogram(context: context, size: size, data: data.blue, color: .blue.opacity(0.6))
                    }
                    .padding(4)
                } else {
                    Text("Histogram")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(height: height)
    }
    
    private func drawHistogram(context: GraphicsContext, size: CGSize, data: [Float], color: Color) {
        guard !data.isEmpty else { return }
        
        let maxValue = data.max() ?? 1.0
        guard maxValue > 0 else { return }
        
        let width = size.width
        let height = size.height
        let binWidth = width / CGFloat(data.count)
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: height))
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * binWidth
            let normalizedValue = min(CGFloat(value / maxValue), 1.0)
            let y = height - (normalizedValue * height * 0.95) // 95% max height
            
            if index == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        
        context.fill(path, with: .color(color))
    }
}

// MARK: - Histogram Generator

@Observable
@MainActor
final class HistogramGenerator: NSObject {
    var histogramData: HistogramData = .empty
    var isEnabled: Bool = true
    
    private let processingQueue = DispatchQueue(label: "com.rawcam.histogram.queue", qos: .userInteractive)
    nonisolated(unsafe) private var frameCounter = 0
    private let frameSkip = 3 // Process every 3rd frame
    
    nonisolated(unsafe) private var videoOutput: AVCaptureVideoDataOutput?
    
    func setupVideoOutput(for session: AVCaptureSession) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Remove existing output if any
            if let existingOutput = self.videoOutput {
                session.removeOutput(existingOutput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.processingQueue)
            
            session.beginConfiguration()
            if session.canAddOutput(output) {
                session.addOutput(output)
                self.videoOutput = output
            }
            session.commitConfiguration()
        }
    }
    
    func enable() {
        isEnabled = true
    }
    
    func disable() {
        isEnabled = false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension HistogramGenerator: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % frameSkip == 0 else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Calculate histogram
        guard let histogramData = calculateHistogramFromPixelBuffer(pixelBuffer) else { return }
        
        Task { @MainActor in
            if self.isEnabled {
                self.histogramData = histogramData
            }
        }
    }
    
    private nonisolated func calculateHistogramFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> HistogramData? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Sample every 4th pixel for performance
        let step = 4
        
        var redHist = [Float](repeating: 0, count: 256)
        var greenHist = [Float](repeating: 0, count: 256)
        var blueHist = [Float](repeating: 0, count: 256)
        
        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4
                
                // BGRA format
                let blue = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let red = Int(pixels[offset + 2])
                
                redHist[red] += 1
                greenHist[green] += 1
                blueHist[blue] += 1
            }
        }
        
        return HistogramData(red: redHist, green: greenHist, blue: blueHist)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HistogramView(data: .empty)
            .frame(width: 150)
        
        // Sample histogram
        HistogramView(data: HistogramData(
            red: (0..<256).map { i in Float(i) * Float(i) / 65536 },
            green: (0..<256).map { i in Float(255 - i) * Float(255 - i) / 65536 },
            blue: (0..<256).map { i in abs(Float(128 - i)) * 2 }
        ))
        .frame(width: 150)
    }
    .padding()
    .background(Color.gray)
}
