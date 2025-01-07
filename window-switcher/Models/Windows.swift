//
//  Windows.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import AppKit
import ScreenCaptureKit

struct Window : Hashable {
    var id: Int
    var appName: String
    var appPID: Int32
    var index: Int
    var name: String
    
    var element: AXUIElement
    
    func hash(into hasher: inout Hasher) {
        return element.hash(into: &hasher)
    }
    
    func fqn() -> String {
        "\(appName): \(name)"
    }
}

class Windows {
    var windows: [Window]
    
    private static func experimental() {
        // Creating a SCStreamConfiguration object
        let streamConfig = SCStreamConfiguration()
                
        // Set output resolution to 1080p
        streamConfig.width = 1920
        streamConfig.height = 1080

        // Set the capture interval at 60 fps
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(60))

        // Hides cursor
        streamConfig.showsCursor = false

        // Enable audio capture
        streamConfig.capturesAudio = true

        // Set sample rate to 48000 kHz stereo
        streamConfig.sampleRate = 48000
        streamConfig.channelCount = 2
    }
    
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
                    
                    windows.append(Window(id: axWindow.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, index: i, name: title, element: axWindow))
                }
            }
        }
        
        return windows
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
