//
//  Windows.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import AppKit

struct Window : Hashable {
    var id: Int
    var appName: String
    var appPID: Int32
    var name: String
    
    var element: AXUIElement
    
    func hash(into hasher: inout Hasher) {
        return element.hash(into: &hasher)
    }
    
    func fqn() -> String {
        "\(appName): \(name)"
    }
}

// getWindowName gets the title attribute of a provided AXUIElement.
func getWindowName(element: AXUIElement) -> String? {
    var titleRef: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    if err == .success, let t = titleRef as? String {
        return t
    } else {
        return nil
    }
}

// handleObserverEvent is a handler for AXUI events.
func handleObserverEvent(observer: AXObserver, element: AXUIElement, notification: CFString, context: UnsafeMutableRawPointer?) -> Void {
    guard let context = context else {
        print("context is nil in callback!") // Crucial check
        return
    }
    let observerSelf = Unmanaged<Windows>.fromOpaque(context).takeUnretainedValue()
    
    switch String(notification) {
    case kAXTitleChangedNotification:
        let windowIdx = observerSelf.windows.firstIndex(where: { $0.element == element })
        guard let windowIdx = windowIdx else {
            print("window not found in windows when handling title change")
            return
        }
        observerSelf.windows[windowIdx].name = getWindowName(element: element)!
        break
    case kAXCreatedNotification:
        let (appPID, _) = observerSelf.applicationObservers.first(where: { $0.value == observer })!
        if let app = NSRunningApplication(processIdentifier: appPID), let title = getWindowName(element: element) {
            let window = Window(id: element.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, name: title, element: element)
            observerSelf.windows.append(window)
        }
        break
    case kAXUIElementDestroyedNotification:
        observerSelf.windows.removeAll(where: { $0.element == element })
        break
    default:
        print("Error: unexpected notification from switch statement")
        exit(1)
    }
}

func getAppsExcludingWindowSwitcher() -> [NSRunningApplication] {
    return NSWorkspace.shared.runningApplications.filter({ $0.processIdentifier != getpid() })
}

class Windows {
    var windows: [Window]
    private var observer: AXObserver? = nil
    var applicationObservers: [Int32: AXObserver?] = [:]
    
    private static func getInitialWindows(_ apps: [NSRunningApplication]) -> [Window] {
        var windows: [Window] = []
        
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            
            var result: CFArray?
            let err = AXUIElementCopyAttributeValues(axApp, kAXWindowsAttribute as CFString, 0, 100, &result)
            // If successfully copied values, conditionally cast to an array of elements.
            if err == .success, let axWindows = result as? [AXUIElement] {
                for axWindow in axWindows {
                    // Get window title.
                    guard let title = getWindowName(element: axWindow) else {
                        continue
                    }
                    
                    windows.append(Window(id: axWindow.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, name: title, element: axWindow))
                }
            }
        }
        
        return windows
    }
    
    private func startObserving(apps: [NSRunningApplication]) {
        for app in apps {
            var observer: AXObserver?
            let err = AXObserverCreate(app.processIdentifier, handleObserverEvent, &observer)
            if err != .success {
                print("Failed to create observer")
                return
            }
            guard let observer = observer else {
                print("Observer is nil")
                exit(1)
            }
            
            // Attach observer to the lifecycle of this struct.
            applicationObservers[app.processIdentifier] = observer
            
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            let element = AXUIElementCreateApplication(app.processIdentifier)
            
            // Add notifications to observe.
            let notifications = [
                kAXTitleChangedNotification,
                kAXCreatedNotification,
                kAXUIElementDestroyedNotification
            ]
            for notification in notifications {
                let err = AXObserverAddNotification(observer, element, notification as CFString, selfPtr)
                if err != .success {
                    #if DEBUG
                    print("err: AXObserver failed to add notification \(notification)")
                    #endif
                }
            }
            
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
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
        
        var results: [(Int16, Window)] = []
        
        // Search through windows for anything that has the query as a substring.
        for window in windows {
            let score = FuzzyCompare(query.lowercased(), window.fqn().lowercased())
            if score != 0 {
                results.append((score, window))
            }
        }
        
        // Sort and return just the windows, without the score.
        results.sort(by: { $0.0 > $1.0 })
        return results.map(\.1)
    }
    
    public func refreshWindows() {
        let apps = getAppsExcludingWindowSwitcher()
        
        // Get apps that have been closed, and apps that are new.
        var deleteObservers = applicationObservers
        var addApps : [NSRunningApplication] = []
        for app in apps {
            let pid = app.processIdentifier
            if applicationObservers.keys.contains(pid) {
                deleteObservers.removeValue(forKey: pid)
            } else {
                addApps.append(app)
            }
        }
        
        // Clean up observers in deleteObservers
        for (pid, observer) in deleteObservers {
            if let observer = observer {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
            applicationObservers.removeValue(forKey: pid)
            
            // Remove windows associated with this app.
            windows = windows.filter { $0.appPID != pid }
        }
        
        // Add new windows for new apps
        windows.append(contentsOf: Windows.getInitialWindows(addApps))
        startObserving(apps: addApps)
    }
    
    init() {
        let apps = getAppsExcludingWindowSwitcher()
        windows = Windows.getInitialWindows(apps)
        startObserving(apps: apps)
    }
}
