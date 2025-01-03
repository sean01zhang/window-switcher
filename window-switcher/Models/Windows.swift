//
//  Windows.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import AppKit
import Cocoa
import ScreenCaptureKit

struct Window {
    var id: Int
    var appName: String
    var appPID: Int32
    var index: Int
    var name: String
    
    var element: AXUIElement
    
    func fqn() -> String {
        "\(appName): \(name)"
    }
}

class Windows {
    var windows: [Window]
    
    private static func getInitialWindows() -> [Window] {
        var windows: [Window] = []
        
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            
            var result: CFArray?
            let err = AXUIElementCopyAttributeValues(axApp, kAXWindowsAttribute as CFString, 0, 100, &result)
            // If successfully copied values, conditionally cast to an array of elements.
            if err == .success, let axWindows = result as? [AXUIElement] {
                for (i, axWindow) in axWindows.enumerated() {
                    // Get window title.
                    var titleRef: CFTypeRef?
                    var title: String
                    let err = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
                    if err == .success, let t = titleRef as? String {
                        title = t
                    } else {
                        continue
                    }
                    
                    getWindowThumbnail(axWindow)
                    
                    windows.append(Window(id: axWindow.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, index: i, name: title, element: axWindow))
                }
            }
        }
        
        return windows
    }
    
    private static async func getWindowThumbnail(_ window: AXUIElement) -> NSImage? {
        // Get the window's position and size.
        var posRef: CFTypeRef?
        var pos: CGPoint = .zero
        let err = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        if err == .success, AXValueGetValue(posRef as! AXValue, .cgPoint, &pos) {
            // No-op.
        } else {
            return nil
        }
        
        var sizeRef: CFTypeRef?
        var size: CGSize = .zero
        let err2 = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        if err2 == .success, AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
            // No-op.
        } else {
            return nil
        }
        
        let bounds = CGRect(origin: pos, size: size)
        
        // Get content that is currently available for capture.
        let availableContent = try await SCShareableContent.current; catch { return nil }
                
        // Create instance of SCContentFilter to record entire display.
        guard let display = availableContent.displays.first else { return nil }
        
        
        var excludedApps = [SCRunningApplication]()
        // Create a content filter with excluded apps.
        filter = SCContentFilter(display: display,
                                 excludingApplications: excludedApps,
                                 exceptingWindows: [])
        
        
        
        var streamConfig = SCStreamConfiguration()


        if let dynamicRangePreset = selectedDynamicRangePreset?.scDynamicRangePreset {
            streamConfig = SCStreamConfiguration(preset: dynamicRangePreset)
        }


        // Configure audio capture.
        streamConfig.capturesAudio = isAudioCaptureEnabled
        streamConfig.excludesCurrentProcessAudio = isAppAudioExcluded
        streamConfig.captureMicrophone = isMicCaptureEnabled


        // Configure the display content width and height.
        if captureType == .display, let display = selectedDisplay {
            streamConfig.width = display.width * scaleFactor
            streamConfig.height = display.height * scaleFactor
        }


        // Configure the window content width and height.
        if captureType == .window, let window = selectedWindow {
            streamConfig.width = Int(window.frame.width) * 2
            streamConfig.height = Int(window.frame.height) * 2
        }


        // Set the capture interval at 60 fps.
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)


        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        streamConfig.queueDepth = 5

    }

    public static func select(_ window: Window) {
        // Raise window to top.
        let err = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        if err != .success {
            print("[\(window.appName)] Error raising window \(err)")
        }
        
        // Activate the application.
        let _ = NSWorkspace.shared
        guard let app = NSRunningApplication(processIdentifier: window.appPID) else {
            print("Could not get running application")
            return
        }
        DispatchQueue.main.async {
            let ok = app.activate()
            if !ok {
                print("(\(window.appName)/\(window.name)) Could not activate application")
                return
            }
        }
    }
    
    public func search(_ query: String) -> [Window] {
        if query.isEmpty {
            return windows
        }
        
        var results: [(Int, Window)] = []
        
        // Search through windows for anything that has the query as a substring.
        for window in windows {
            if window.fqn().lowercased().contains(query.lowercased()) {
                let score = abs(window.fqn().lengthOfBytes(using: .utf8) - query.lengthOfBytes(using: .utf8))
                results.append((score, window))
            }
        }
        
        // Sort and return just the windows, without the score.
        results.sort(by: { $0.0 < $1.0 })
        return results.map(\.1)
    }
    
    init() {
        windows = Windows.getInitialWindows()
    }
    
    public func refreshWindows() {
        windows = Windows.getInitialWindows()
    }
}
