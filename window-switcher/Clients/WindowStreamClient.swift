//
//  WindowStreams.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-04.
//

import ScreenCaptureKit

func SCWindowKey(window: SCWindow) -> String {
    "\(window.owningApplication?.applicationName ?? ""): \(window.title ?? "")"
}

// WindowStreams will hold a buffer of WindowStreams
@MainActor
class WindowStreamClient {
    private var windowMap: [Window: SCWindow] = [:]
    private var initialLoadTask: Task<Void, Never>?
    
    init(_ windows: [Window]) {
        initialLoadTask = Task { [weak self] in
            await self?.loadInitialMap(for: windows)
        }
    }

    deinit {
        initialLoadTask?.cancel()
    }

    private func loadInitialMap(for windows: [Window]) async {
        defer {
            initialLoadTask = nil
        }

        do {
            windowMap = try await getInitialMap(for: windows)
        } catch is CancellationError {
            return
        } catch {
            print("error: get initial map: \(error)")
        }
    }
    
    private static func getImage(for window: SCWindow) async throws -> CGImage {
        let streamConfig = SCStreamConfiguration()
        
        // Set output resolution to a small size
        streamConfig.width = Int(window.frame.width)
        streamConfig.height = Int(window.frame.height)

        // Set the capture interval to get only one frame
        streamConfig.minimumFrameInterval = .invalid
        streamConfig.showsCursor = true
        streamConfig.capturesAudio = false
        streamConfig.backgroundColor = CGColor.clear
        streamConfig.ignoreShadowsSingleWindow = false
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA // Get an alpha channel.
        
        let filter = SCContentFilter(desktopIndependentWindow: window)
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: streamConfig)
    }

    public func refresh(_ windows: [Window]) async throws {
        initialLoadTask = nil
        windowMap = try await getInitialMap(for: windows)
    }
    
    public func getWindowPreview(for window: Window) async throws -> CGImage? {
        if let initialLoadTask {
            await initialLoadTask.value
        }

        if let w = windowMap[window] {
            return try await WindowStreamClient.getImage(for: w)
        } else {
            return nil
        }
    }
    
    private func getInitialMap(for windows: [Window]) async throws -> [Window: SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        
        var fqnToWindow : [String : Window] = [:]
        for window in windows {
            fqnToWindow[window.fqn()] = window
        }
            
        var windowMap : [Window: SCWindow] = [:]
        for scWindow in content.windows {
            let key = SCWindowKey(window: scWindow)
            if let window = fqnToWindow[key] {
                windowMap[window] = scWindow
            }
        }
        
        return windowMap
    }
}
