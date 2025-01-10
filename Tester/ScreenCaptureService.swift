import Foundation
import ScreenCaptureKit
import CoreImage
import Vision
import AppKit

class ScreenCaptureService: ObservableObject {
    @Published var detectedQRCodes: [String] = []
    private var stream: SCStream?
    private let streamOutput = ScreenCaptureStreamOutput()
    
    // Track consecutive frames and timing
    private var consecutiveFrames: [[String]] = []
    private let requiredConsecutiveFrames = 2
    private var lastFrameTime: Date?
    private let staticThreshold: TimeInterval = 0.75 // Consider screen static after 0.75 seconds
    
    init() {
        streamOutput.qrCodeHandler = { [weak self] codes in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.processNewFrame(codes)
            }
        }
    }
    
    private func processNewFrame(_ codes: [String]) {
        let currentTime = Date()
        // Add new frame - sort the codes alphabetically after removing duplicates
        let uniqueCodes = Self.uniqueElementsWithOrder(codes).sorted()
        consecutiveFrames.append(uniqueCodes)
        
        // Keep only the last N frames
        if consecutiveFrames.count > requiredConsecutiveFrames {
            consecutiveFrames.removeFirst()
        }
        
        // Check if screen is static (no frames received for a while)
        if let lastTime = lastFrameTime,
           currentTime.timeIntervalSince(lastTime) >= staticThreshold,
           !consecutiveFrames.isEmpty {
            // Screen is static, use the last frame
            let sortedCurrentCodes = detectedQRCodes.sorted()
            if sortedCurrentCodes != consecutiveFrames.last {
                detectedQRCodes = consecutiveFrames.last ?? []
            }
        }
        // Otherwise check for consecutive matching frames
        else if consecutiveFrames.count == requiredConsecutiveFrames &&
                consecutiveFrames.allSatisfy({ $0 == consecutiveFrames[0] }) {
            let sortedCurrentCodes = detectedQRCodes.sorted()
            if sortedCurrentCodes != consecutiveFrames[0] {
                detectedQRCodes = consecutiveFrames[0]
            }
        }
        
        lastFrameTime = currentTime
    }
    
    private static func uniqueElementsWithOrder(_ array: [String]) -> [String] {
        var seen = Set<String>()
        return array.filter { element in
            if seen.contains(element) {
                return false
            } else {
                seen.insert(element)
                return true
            }
        }
    }
    
    func startCapture() async {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else { return }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            let configuration = SCStreamConfiguration()
            configuration.width = Int(display.width * 2)
            configuration.height = Int(display.height * 2)
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2) // 2 FPS
            
            stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            try stream?.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .global())
            try await stream?.startCapture()
        } catch {
            print("Failed to start capture: \(error)")
        }
    }
}

class ScreenCaptureStreamOutput: NSObject, SCStreamOutput {
    var qrCodeHandler: (([String]) -> Void)?
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        detectQRCodes(in: ciImage)
    }
    
    private func detectQRCodes(in image: CIImage) {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard error == nil else { return }
            
            let codes = request.results?
                .compactMap { $0 as? VNBarcodeObservation }
                .filter { $0.symbology == .qr }
                .compactMap { $0.payloadStringValue } ?? []
            
            self?.qrCodeHandler?(codes)
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        try? handler.perform([request])
    }
} 
