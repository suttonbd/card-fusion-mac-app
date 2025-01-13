import Foundation
import ScreenCaptureKit
import CoreImage
import Vision
import AppKit

// Structure to hold QR code data with position
struct QRCodeWithPosition: Equatable {
    let text: String
    let xPosition: CGFloat
    
    static func == (lhs: QRCodeWithPosition, rhs: QRCodeWithPosition) -> Bool {
        lhs.text == rhs.text
    }
}

class ScreenCaptureService: ObservableObject {
    @Published var detectedQRCodes: [String] = []
    private var stream: SCStream?
    private let streamOutput = ScreenCaptureStreamOutput()
    
    // Track consecutive frames and timing
    private var consecutiveFrames: [[QRCodeWithPosition]] = []
    private let requiredConsecutiveFrames = 2
    private var lastFrameTime: Date?
    private let staticThreshold: TimeInterval = 0.75
    
    init() {
        streamOutput.qrCodeHandler = { [weak self] codes in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.processNewFrame(codes)
            }
        }
    }
    
    private func processNewFrame(_ codes: [(text: String, bounds: CGRect)]) {
        let currentTime = Date()
        // Convert to QRCodeWithPosition and sort by x position
        let positionedCodes = codes.map { QRCodeWithPosition(text: $0.text, xPosition: $0.bounds.minX) }
            .sorted { $0.xPosition < $1.xPosition }
        
        // Remove duplicates keeping leftmost occurrence
        let uniqueCodes = Self.uniqueElementsWithOrder(positionedCodes)
        consecutiveFrames.append(uniqueCodes)
        
        // Keep only the last N frames
        if consecutiveFrames.count > requiredConsecutiveFrames {
            consecutiveFrames.removeFirst()
        }
        
        // Check if screen is static
        if let lastTime = lastFrameTime,
           currentTime.timeIntervalSince(lastTime) >= staticThreshold,
           !consecutiveFrames.isEmpty {
            updateDetectedCodes(consecutiveFrames.last ?? [])
        }
        // Check for consecutive matching frames
        else if consecutiveFrames.count == requiredConsecutiveFrames &&
                consecutiveFrames.allSatisfy({ $0 == consecutiveFrames[0] }) {
            updateDetectedCodes(consecutiveFrames[0])
        }
        
        lastFrameTime = currentTime
    }
    
    private func updateDetectedCodes(_ codes: [QRCodeWithPosition]) {
        let newCodes = codes.map { $0.text }
        if newCodes != detectedQRCodes {
            detectedQRCodes = newCodes
        }
    }
    
    private static func uniqueElementsWithOrder(_ array: [QRCodeWithPosition]) -> [QRCodeWithPosition] {
        var seen = Set<String>()
        return array.filter { element in
            if seen.contains(element.text) {
                return false
            } else {
                seen.insert(element.text)
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
    var qrCodeHandler: (([(text: String, bounds: CGRect)]) -> Void)?
    
    override init() {
        super.init()
    }
    
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
                .map { ($0.payloadStringValue ?? "", $0.boundingBox) }
                .filter { $0.0.isEmpty == false } ?? []
            
            self?.qrCodeHandler?(codes)
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        try? handler.perform([request])
    }
} 
