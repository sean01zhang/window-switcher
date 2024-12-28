//
//  Windows.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import AppKit

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
                    
                    print(axWindow)
                    
                    windows.append(Window(id: axWindow.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, index: i, name: title, element: axWindow))
                }
            } else {
                // TODO: Remove debugging
                print("\(err)")
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
        let ok = app.activate(from: app)
        if !ok {
            print("(\(window.appName)/\(window.name)) Could not activate application")
            return
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
    
    // TODO: Remove this
    private static func testWindows() -> [Window] {
        let names = [
            "Firefox", "Chrome", "Microsoft Edge", "Brave", "Opera", "Safari",
            "Obsidian", "Terminal", "Visual Studio Code", "Visual Studio", "iTerm2",
            "Sublime Text", "Atom", "Discord", "Telegram", "Slack", "Twitter",
        ]
        let testElem = AXUIElementCreateApplication(0)

        return names.enumerated().map{ (index, name) -> Window in
            return Window(id: index, appName: "Sean", appPID: 0, index: 0, name: name, element: testElem)
        }
    }
    
    init() {
        windows = Windows.getInitialWindows()
        
        // TODO: Remove this
        if windows.isEmpty {
            windows = Windows.testWindows()
        }
        
    }
}
