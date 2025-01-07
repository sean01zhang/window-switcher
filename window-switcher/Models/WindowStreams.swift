//
//  WindowStreams.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-04.
//

import ScreenCaptureKit
import VideoToolbox

func SCWindowKey(window: SCWindow) -> String {
    "\(window.owningApplication?.applicationName ?? ""): \(window.title ?? "")"
}

// WindowStreams will hold a buffer of WindowStreams
class WindowStreams {
    var streams: [Window: WindowStream] = [:]
    
    init() {}
    
    // createStreams creates streams for each window in windows.
    func createStreams(for windows: [Window]) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                
                var fqnToWindow : [String : Window] = [:]
                for window in windows {
                    fqnToWindow[window.fqn()] = window
                }
                
                for scWindow in content.windows {
                    let key = SCWindowKey(window: scWindow)
                    if let window = fqnToWindow[key] {
                        streams[window] = WindowStream(for: scWindow)
                    }
                }
            } catch {
                exit(EXIT_FAILURE)
            }
        }
    }
}

// WindowStream should handle occassional image updates & stream open/closing
class WindowStream : NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream : SCStream?
    private let videoSampleBufferQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoSampleBufferQueue")
    
    @Published var capturedImage: CGImage?
    
    private var timer: Timer?
    
    // init starts the WindowStream.
    init(for window: SCWindow) {
        self.stream = nil
        self.timer = nil
        super.init()

        Task {
            do {
                self.stream = try await newStream(for: window)
            } catch {
                print("Why would you fail here?")
            }
        }
    }

    func startUpdates() {
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                // Update image by capturing stream.
                DispatchQueue.main.async {
                    Task {
                        do {
                            try await self.stream?.startCapture()
                            try await self.stream?.stopCapture()
                        } catch {
                            print("failed to create capture")
                        }
                    }
                }
            }
            timer?.fire()
        } else {
            print("Timer not nil?")
        }
    }
    
    func stopUpdates() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
        
    // newStream creates a new SCStream from an SCWindow provided, and
    // sets the streams delegate to itself.
    private func newStream(for window: SCWindow) async throws -> SCStream {
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

        DispatchQueue.main.async {
            self.capturedImage = cgImage
        }
    }
}
