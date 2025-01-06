//
//  Windows.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import AppKit
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
    
    var streams: WindowStreams = WindowStreams()
    
//    func observeApplicationOpens() {
//        let systemWideElement = AXUIElementCreateSystemWide()
//        var observer: AXObserver?
//        let observerCreateStatus = AXObserverCreate(ProcessInfo.processInfo.processIdentifier, { observer, element, notification, userInfo in
//                guard let notificationName = notification as String? else { return }
//
//                if notificationName == kAXApplicationActivatedNotification {
//                    // A new application has been activated (meaning it likely just launched or became frontmost)
//                    print("Application Activated!")
//
//                    // Get the application's process ID
//                    var pid: pid_t = 0
//                    let pidResult = AXUIElementGetPid(element, &pid)
//
//                    if pidResult == .success {
//                        print("Activated Application PID: \(pid)")
//
//                        // Get the application's bundle identifier (optional)
//                        if let app = NSRunningApplication(processIdentifier: pid), let bundleIdentifier = app.bundleIdentifier {
//                            print("Activated Application Bundle Identifier: \(bundleIdentifier)")
//                        }
//
//                        // Get the application's name (optional)
//                        var appName: AnyObject?
//                        let nameResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &appName)
//                        if nameResult == .success, let name = appName as? String {
//                            print("Activated Application Name: \(name)")
//                        }
//                    } else {
//                        print("Could not get PID of activated application. Error code: \(pidResult)")
//                    }
//                }
//            }, &observer)
//
//            guard observerCreateStatus == .success, let observer = observer else {
//                print("Could not create AXObserver")
//                return
//            }
//
//            // Add the notification to the observer, observing the system-wide element
//            let addNotificationStatus = AXObserverAddNotification(observer, systemWideElement, kAXApplicationActivatedNotification as CFString, nil)
//
//            if addNotificationStatus != .success {
//                print("Could not add notification: \(addNotificationStatus)")
//                return
//            }
//
//            // Run the run loop on a background thread
//            DispatchQueue.global(qos: .background).async {
//                CFRunLoopRun()
//            }
//    }
   
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
//        Windows.experimental()
        windows = Windows.getInitialWindows()
    }
    
    public func refreshWindows() {
        windows = Windows.getInitialWindows()
    }
}
