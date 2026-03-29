//
//  WindowStreams.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-04.
//

import ScreenCaptureKit

private struct WindowFrameKey: Hashable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init(_ frame: CGRect) {
        x = Int(frame.origin.x.rounded())
        y = Int(frame.origin.y.rounded())
        width = Int(frame.size.width.rounded())
        height = Int(frame.size.height.rounded())
    }
}

private struct WindowIdentityKey: Hashable {
    let title: WindowTitleKey
    let frame: WindowFrameKey
}

private extension Window {
    var previewTitleKey: WindowTitleKey {
        WindowTitleKey(appPID: appPID, title: name)
    }

    var previewIdentityKey: WindowIdentityKey? {
        guard let frame else {
            return nil
        }

        return WindowIdentityKey(title: previewTitleKey, frame: WindowFrameKey(frame))
    }
}

private extension SCWindow {
    var previewTitleKey: WindowTitleKey? {
        guard let title, let appPID = owningApplication?.processID else {
            return nil
        }

        return WindowTitleKey(appPID: appPID, title: title)
    }

    var previewIdentityKey: WindowIdentityKey? {
        guard let title = previewTitleKey else {
            return nil
        }

        return WindowIdentityKey(title: title, frame: WindowFrameKey(frame))
    }
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
    
    public func getWindowPreview(for window: Window, among windows: [Window]) async throws -> CGImage? {
        if let initialLoadTask {
            await initialLoadTask.value
        }

        if windowMap[window] == nil {
            try await refresh(windows)
        }

        guard let w = windowMap[window] else {
            return nil
        }

        return try await WindowStreamClient.getImage(for: w)
    }
    
    private func getInitialMap(for windows: [Window]) async throws -> [Window: SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        
        var windowsByIdentity: [WindowIdentityKey: [Window]] = [:]
        var windowsByTitle: [WindowTitleKey: [Window]] = [:]
        for window in windows {
            windowsByTitle[window.previewTitleKey, default: []].append(window)
            if let key = window.previewIdentityKey {
                windowsByIdentity[key, default: []].append(window)
            }
        }

        var matchedWindows: Set<Window> = []
        var windowMap: [Window: SCWindow] = [:]
        for scWindow in content.windows {
            if let key = scWindow.previewIdentityKey,
               let window = Self.popFirst(for: key, from: &windowsByIdentity, excluding: matchedWindows) {
                matchedWindows.insert(window)
                windowMap[window] = scWindow
                continue
            }

            if let title = scWindow.previewTitleKey,
               let window = Self.uniqueCandidate(for: title, from: windowsByTitle, excluding: matchedWindows) {
                matchedWindows.insert(window)
                windowMap[window] = scWindow
            }
        }
        
        return windowMap
    }

    private static func popFirst<Key: Hashable>(for key: Key, from matches: inout [Key: [Window]], excluding matchedWindows: Set<Window>) -> Window? {
        guard var windows = matches[key] else {
            return nil
        }

        windows.removeAll(where: { matchedWindows.contains($0) })
        guard let window = windows.first else {
            matches.removeValue(forKey: key)
            return nil
        }

        windows.removeFirst()
        if windows.isEmpty {
            matches.removeValue(forKey: key)
        } else {
            matches[key] = windows
        }

        return window
    }

    private static func uniqueCandidate(for key: WindowTitleKey, from matches: [WindowTitleKey: [Window]], excluding matchedWindows: Set<Window>) -> Window? {
        let candidates = (matches[key] ?? []).filter { !matchedWindows.contains($0) }
        guard candidates.count == 1 else {
            return nil
        }

        return candidates[0]
    }
}
