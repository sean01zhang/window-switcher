//
//  WindowStreams.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-04.
//

import ScreenCaptureKit
import VideoToolbox

class WindowStreams : NSObject, SCStreamOutput, SCStreamDelegate {
    var streams: [String: SCStream] = [:]
    @Published var capturedImage: CGImage?
    var images: [String: CGImage] = [:]
    
    private let videoSampleBufferQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoSampleBufferQueue")

    override init() {
        super.init()
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                
                for window in content.windows {
                    let key = "\(window.owningApplication?.applicationName ?? ""): \(window.title ?? "")"
                    let stream = try await getStream(for: window)
                    streams[key] = stream
                    try await streams[key]?.startCapture()
                    
                    if let img = capturedImage {
                        images[key] = capturedImage
                    }
                    
                    try await streams[key]?.stopCapture()
                }
            } catch {
                print("Fuck window thumbnaisl")
            }
        }
    }
    
    private func getStream(for window: SCWindow) async throws -> SCStream {
        let streamConfig = SCStreamConfiguration()
        
        // Set output resolution to a small size
        streamConfig.width = Int(window.frame.width)
        streamConfig.height = Int(window.frame.height)

        // Set the capture interval at 60 fps
        streamConfig.minimumFrameInterval = .invalid
        streamConfig.showsCursor = true
        streamConfig.capturesAudio = false
        streamConfig.backgroundColor = CGColor.clear
        streamConfig.ignoreShadowsSingleWindow = false
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA // Get an alpha channel.

        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        // Create a capture stream with the filter and stream configuration
        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        // Add a stream output to capture screen content.
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        
        return stream
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
        
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let cgImage else {
            return
        }
        
        capturedImage = cgImage
    }
}
