import AppKit

private func getWindowName(element: AXUIElement) -> String? {
    var titleRef: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    if err == .success, let t = titleRef as? String {
        return t
    } else {
        return nil
    }
}

private func handleObserverEvent(observer: AXObserver, element: AXUIElement, notification: CFString, context: UnsafeMutableRawPointer?) {
    guard let context = context else {
        print("context is nil in callback!")
        return
    }

    let client = Unmanaged<WindowClient>.fromOpaque(context).takeUnretainedValue()
    client.processNotification(observer: observer, element: element, notification: notification)
}

final class WindowClient {
    private var windows: [Window]
    private var applicationObservers: [Int32: AXObserver?] = [:]

    init() {
        let apps = WindowClient.getApps()
        windows = WindowClient.getInitialWindows(apps)
        startObserving(apps: apps)
    }

    deinit {
        resetObservers()
    }

    func getWindows() -> [Window] {
        return windows
    }

    func focusWindow(_ window: Window) {
        let err = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        if err != .success {
            print("[\(window.appName)] Error raising window \(err)")
        }

        guard let app = NSRunningApplication(processIdentifier: window.appPID) else {
            print("Could not get running application")
            return
        }
        DispatchQueue.main.async {
            if !app.activate() {
                print("(\(window.appName)/\(window.name)) Could not activate application")
            }
        }
    }

    func refresh() {
        let apps = WindowClient.getApps()
        windows = WindowClient.getInitialWindows(apps)
        resetObservers()
        startObserving(apps: apps)
    }

    private func startObserving(apps: [NSRunningApplication]) {
        for app in apps {
            var observer: AXObserver?
            let err = AXObserverCreate(app.processIdentifier, handleObserverEvent, &observer)
            if err != .success {
                print("Failed to create observer")
                continue
            }
            guard let observer else {
                print("Observer is nil")
                continue
            }

            applicationObservers[app.processIdentifier] = observer

            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            let element = AXUIElementCreateApplication(app.processIdentifier)
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

    private func resetObservers() {
        for (_, observer) in applicationObservers {
            if let observer {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }
        applicationObservers.removeAll()
    }

    fileprivate func processNotification(observer: AXObserver, element: AXUIElement, notification: CFString) {
        switch String(notification) {
        case kAXTitleChangedNotification:
            guard let windowIdx = windows.firstIndex(where: { $0.element == element }) else {
                print("window not found in windows when handling title change")
                return
            }
            guard let newName = getWindowName(element: element) else {
                print("Error: could not get new name for window")
                windows.remove(at: windowIdx)
                return
            }
            windows[windowIdx].name = newName
        case kAXCreatedNotification:
            guard let (appPID, _) = applicationObservers.first(where: { $0.value == observer }) else {
                print("observer pid not found for created notification")
                return
            }
            if let app = NSRunningApplication(processIdentifier: appPID), let title = getWindowName(element: element) {
                let window = Window(id: element.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, name: title, element: element)
                if !windows.contains(window) {
                    windows.append(window)
                }
            }
        case kAXUIElementDestroyedNotification:
            windows.removeAll(where: { $0.element == element })
        default:
            print("Error: unexpected notification from switch statement")
        }
    }

    private static func getApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter({ $0.activationPolicy == .regular })
    }

    private static func getInitialWindows(_ apps: [NSRunningApplication]) -> [Window] {
        var windows: [Window] = []

        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var result: CFArray?
            let err = AXUIElementCopyAttributeValues(axApp, kAXWindowsAttribute as CFString, 0, 100, &result)
            if err == .success, let axWindows = result as? [AXUIElement] {
                for axWindow in axWindows {
                    guard let title = getWindowName(element: axWindow) else {
                        continue
                    }
                    windows.append(Window(id: axWindow.hashValue, appName: app.localizedName ?? "Unknown", appPID: app.processIdentifier, name: title, element: axWindow))
                }
            }
        }

        return windows
    }
}
