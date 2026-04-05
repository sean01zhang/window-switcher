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
    private var previewCache: [WindowIdentityKey: CGImage] = [:]
    private var initialLoadTask: Task<Void, Never>?
    
    // Asynchronously builds the window map and prefetches all previews.
    // Not guaranteed to complete before user interaction; getWindowPreview
    // awaits this task and falls back to on-demand capture if needed.
    init(_ windows: [Window]) {
        initialLoadTask = Task { [weak self] in
            await self?.loadInitialMap(for: windows)
            await self?.captureAllPreviews(for: windows)
            await MainActor.run { self?.initialLoadTask = nil }
        }
    }

    deinit {
        initialLoadTask?.cancel()
    }

    private func loadInitialMap(for windows: [Window]) async {
        do {
            windowMap = try await getInitialMap(for: windows)
            prunePreviewCache(for: windows)
        } catch is CancellationError {
            return
        } catch {
            print("error: get initial map: \(error)")
        }
    }
    
    private nonisolated static func getImage(for window: SCWindow) async throws -> CGImage {
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
        windowMap = try await getInitialMap(for: windows)
        prunePreviewCache(for: windows)
        await captureAllPreviews(for: windows)
    }

    private static let maxConcurrentCaptures = 4

    private func captureAllPreviews(for windows: [Window]) async {
        await withTaskGroup(of: Void.self) { group in
            var inFlight = 0
            for window in windows {
                if let key = window.previewIdentityKey, previewCache[key] != nil {
                    continue
                }
                guard let scWindow = windowMap[window] else { continue }
                if inFlight >= Self.maxConcurrentCaptures {
                    await group.next()
                    inFlight -= 1
                }
                group.addTask {
                    do {
                        let image = try await WindowStreamClient.getImage(for: scWindow)
                        await MainActor.run { [weak self] in
                            self?.cache(image, for: window)
                        }
                    } catch is CancellationError {
                        return
                    } catch {
                        print("error: capture preview: \(error)")
                    }
                }
                inFlight += 1
            }
        }
    }

    public func cachedWindowPreview(for window: Window) -> CGImage? {
        guard let key = window.previewIdentityKey else {
            return nil
        }

        return previewCache[key]
    }
    
    public func getWindowPreview(for window: Window, among windows: [Window]) async throws -> CGImage? {
        if let cached = cachedWindowPreview(for: window) {
            return cached
        }

        if let initialLoadTask {
            await initialLoadTask.value
        }

        if let cached = cachedWindowPreview(for: window) {
            return cached
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
