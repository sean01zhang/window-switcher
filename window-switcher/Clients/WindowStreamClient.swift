//
//  WindowStreams.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-04.
//
import Observation
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
@Observable
class WindowStreamClient {
    private var windowMap: [Window: SCWindow] = [:]
    private var previewCache: [WindowIdentityKey: CGImage] = [:]
    @ObservationIgnored
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
            prunePreviewCache(for: windows)
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
        prunePreviewCache(for: windows)
    }

    public func cachedWindowPreview(for window: Window) -> CGImage? {
        guard let key = window.previewIdentityKey else {
            return nil
        }

        return previewCache[key]
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

        let preview = try await WindowStreamClient.getImage(for: w)
        cache(preview, for: window)
        return preview
    }
    
    private func getInitialMap(for windows: [Window]) async throws -> [Window: SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        
        var scWindowsById: [CGWindowID: SCWindow] = [:]
        for scWindow in content.windows {
            scWindowsById[scWindow.windowID] = scWindow
        }

        var windowMap: [Window: SCWindow] = [:]
        var unmatchedWindows: [Window] = []

        // 1. First pass: Match precisely by CGWindowID
        for window in windows {
            if let windowID = window.windowID, let scWindow = scWindowsById[windowID] {
                windowMap[window] = scWindow
            } else {
                unmatchedWindows.append(window)
            }
        }

        // 2. Second pass: Fall back to heuristics for any unmatched windows
        if !unmatchedWindows.isEmpty {
            var windowsByIdentity: [WindowIdentityKey: [Window]] = [:]
            var windowsByTitle: [WindowTitleKey: [Window]] = [:]
            for window in unmatchedWindows {
                windowsByTitle[window.previewTitleKey, default: []].append(window)
                if let key = window.previewIdentityKey {
                    windowsByIdentity[key, default: []].append(window)
                }
            }

            var matchedWindows: Set<Window> = []
            for scWindow in content.windows {
                // Skip if this scWindow is already matched to a window in the first pass
                if windowMap.values.contains(where: { $0.windowID == scWindow.windowID }) {
                    continue
                }

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

    private func cache(_ preview: CGImage?, for window: Window) {
        guard let preview else {
            return
        }

        if let key = window.previewIdentityKey {
            previewCache[key] = preview
        }
    }

    private func prunePreviewCache(for windows: [Window]) {
        let validIdentityKeys = Set(windows.compactMap(\.previewIdentityKey))
        previewCache = previewCache.filter { validIdentityKeys.contains($0.key) }
    }
}
