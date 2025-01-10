import Foundation
import ScreenCaptureKit
import CoreImage
import Vision
import AppKit

class ScreenCaptureService: ObservableObject {
    @Published var detectedQRCodes: [String] = []
    private var stream: SCStream?
    private let streamOutput = ScreenCaptureStreamOutput()
    
    init() {
        streamOutput.qrCodeHandler = { [weak self] codes in
            DispatchQueue.main.async {
                self?.detectedQRCodes = codes
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
