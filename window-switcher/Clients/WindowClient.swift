import AppKit



@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

private extension AXUIElement {
    func getAttributeValue(_ attribute: CFString) -> CFTypeRef? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute, &valueRef) == .success else {
            return nil
        }
        return valueRef
    }

    func getElementAttribute(_ attribute: CFString) -> AXUIElement? {
        guard let valueRef = getAttributeValue(attribute) else {
            return nil
        }
        if CFGetTypeID(valueRef) == AXUIElementGetTypeID() {
            return (valueRef as! AXUIElement)
        }
        return nil
    }

    var role: String? {
        getAttributeValue(kAXRoleAttribute as CFString) as? String
    }

    var isWindow: Bool {
        role == kAXWindowRole as String
    }

    var windowTitle: String? {
        guard let title = getAttributeValue(kAXTitleAttribute as CFString) as? String else {
            return nil
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var windowFrame: CGRect? {
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID() else {
            return nil
        }
        let position = positionRef as! AXValue
        guard AXValueGetType(position) == .cgPoint else {
            return nil
        }

        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let sizeRef,
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
            return nil
        }
        let size = sizeRef as! AXValue
        guard AXValueGetType(size) == .cgSize else {
            return nil
        }

        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &origin),
              AXValueGetValue(size, .cgSize, &dimensions) else {
            return nil
        }

        return CGRect(origin: origin, size: dimensions)
    }

    var windowID: CGWindowID? {
        var cgWindowID: CGWindowID = 0
        return (_AXUIElementGetWindow(self, &cgWindowID) == .success) ? cgWindowID : nil
    }

    var processIdentifier: pid_t? {
        var pid: pid_t = 0
        return (AXUIElementGetPid(self, &pid) == .success) ? pid : nil
    }
}

extension NSRunningApplication {
    var requiresAXEnhancedUserInterface: Bool {
        guard let bundleID = bundleIdentifier else { return false }
        let id = bundleID.lowercased()
        return id.contains("chrome") || id.contains("chromium")
    }
}

extension Window {
    init?(element: AXUIElement, fallbackApp: NSRunningApplication) {
        guard element.isWindow else {
            return nil
        }

        let resolvedApp: NSRunningApplication
        if let pid = element.processIdentifier,
           let actualApp = NSRunningApplication(processIdentifier: pid) {
            resolvedApp = actualApp
        } else {
            resolvedApp = fallbackApp
        }

        var title = element.windowTitle
        if title == nil || title?.isEmpty == true {
            // General Rule: Any real window (having a CGWindowID) that lacks a title
            // falls back to its application's localized name.
            if let tempID = element.windowID, tempID != 0 {
                title = resolvedApp.localizedName ?? "Application Window"
            }
        }

        guard let windowTitle = title, !windowTitle.isEmpty else {
            return nil
        }

        self.id = element.hashValue
        self.appName = resolvedApp.localizedName ?? "Unknown"
        self.appPID = resolvedApp.processIdentifier
        self.name = windowTitle
        self.frame = element.windowFrame
        self.element = element
        self.windowID = element.windowID
    }
}

private func handleObserverEvent(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    context: UnsafeMutableRawPointer?
) {
    guard let context else {
        print("context is nil in callback!")
        return
    }

    let client = Unmanaged<WindowClient>.fromOpaque(context).takeUnretainedValue()
    client.processNotification(observer: observer, element: element, notification: notification)
}

final class WindowClient {
    private var windows: [Window]
    private var recentWindowKeys: [WindowRecentUseKey]
    private var applicationObservers: [Int32: AXObserver] = [:]
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
    private var workspaceObservers: [NSObjectProtocol] = []

    init() {
        let apps = Self.getApps()
        windows = Self.getInitialWindows(apps)
        recentWindowKeys = Self.seedRecentWindowKeys(for: windows)
        startObserving(apps: apps)
        startObservingWorkspace()
    }

    deinit {
        resetWorkspaceObservers()
        resetObservers()
    }

    func getWindows() -> [Window] {
        windows
    }

    func getWindowsByRecentUse() -> [Window] {
        WindowRecentUse.orderedWindows(windows, recentKeys: recentWindowKeys)
    }

    func focusWindow(_ window: Window) {
        moveWindowToFront(window)

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
        let apps = Self.getApps()
        windows = Self.getInitialWindows(apps)
        recentWindowKeys = Self.seedRecentWindowKeys(for: windows)
        resetObservers()
        startObserving(apps: apps)
    }

    private func startObservingWorkspace() {
        workspaceObservers = [
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                self?.handleWorkspaceLaunch(notification)
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                self?.handleWorkspaceTermination(notification)
            }
        ]
    }

    private func resetWorkspaceObservers() {
        for observer in workspaceObservers {
            workspaceNotificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func handleWorkspaceLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular else {
            return
        }

        syncWindows(for: app.processIdentifier)
        startObserving(apps: [app])
    }

    private func handleWorkspaceTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        removeObserver(for: app.processIdentifier)
        removeWindows(for: app.processIdentifier)
    }

    private func startObserving(apps: [NSRunningApplication]) {
        for app in apps where applicationObservers[app.processIdentifier] == nil {
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
            if app.requiresAXEnhancedUserInterface {
                AXUIElementSetAttributeValue(element, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
            }
            let notifications: [CFString] = [
                kAXTitleChangedNotification as CFString,
                kAXWindowCreatedNotification as CFString,
                kAXWindowMovedNotification as CFString,
                kAXWindowResizedNotification as CFString,
                kAXWindowMiniaturizedNotification as CFString,
                kAXWindowDeminiaturizedNotification as CFString,
                kAXApplicationActivatedNotification as CFString,
                kAXApplicationHiddenNotification as CFString,
                kAXApplicationShownNotification as CFString,
                kAXFocusedWindowChangedNotification as CFString,
                kAXMainWindowChangedNotification as CFString,
                kAXUIElementDestroyedNotification as CFString
            ]

            for notification in notifications {
                let err = AXObserverAddNotification(observer, element, notification, selfPtr)
                if err != .success {
                    #if DEBUG
                    print("err: AXObserver failed to add notification \(notification)")
                    #endif
                }
            }

            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    private func removeObserver(for appPID: Int32) {
        guard let observer = applicationObservers.removeValue(forKey: appPID) else {
            return
        }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func resetObservers() {
        for appPID in Array(applicationObservers.keys) {
            removeObserver(for: appPID)
        }
    }

    private func appPID(for observer: AXObserver) -> Int32? {
        applicationObservers.first(where: { $0.value == observer })?.key
    }

    private func replaceWindows(for appPID: Int32, with updatedWindows: [Window]) {
        let insertIndex = windows.firstIndex(where: { $0.appPID == appPID }) ?? windows.count
        windows.removeAll(where: { $0.appPID == appPID })
        windows.insert(contentsOf: updatedWindows, at: min(insertIndex, windows.count))
        reconcileRecentWindowKeys()
    }

    private func removeWindows(for appPID: Int32) {
        windows.removeAll(where: { $0.appPID == appPID })
        reconcileRecentWindowKeys()
    }

    private func syncWindows(for appPID: Int32) {
        guard let app = NSRunningApplication(processIdentifier: appPID),
              app.activationPolicy == .regular else {
            removeWindows(for: appPID)
            return
        }

        replaceWindows(for: appPID, with: Self.getWindows(for: app))
    }

    private func syncWindowIfNeeded(observer: AXObserver, element: AXUIElement) {
        guard element.isWindow,
              let appPID = appPID(for: observer) else {
            return
        }

        syncWindows(for: appPID)
    }

    private func reconcileRecentWindowKeys() {
        recentWindowKeys = WindowRecentUse.reconcile(
            recentWindowKeys,
            with: windows.map(WindowIdentityDescriptors.recentUseKey(for:))
        )
    }

    private func moveWindowToFront(_ window: Window) {
        recentWindowKeys = WindowRecentUse.movingToFront(
            WindowIdentityDescriptors.recentUseKey(for: window),
            in: recentWindowKeys
        )
    }

    private func moveTrackedWindowToFront(element: AXUIElement) -> Bool {
        guard let window = windows.first(where: { $0.element == element }) else {
            return false
        }

        moveWindowToFront(window)
        return true
    }

    private func moveFocusedWindowToFront(for appPID: Int32) {
        let appElement = AXUIElementCreateApplication(appPID)

        if let focusedWindow = appElement.getElementAttribute(kAXFocusedWindowAttribute as CFString),
           moveTrackedWindowToFront(element: focusedWindow) {
            return
        }

        if let mainWindow = appElement.getElementAttribute(kAXMainWindowAttribute as CFString) {
            _ = moveTrackedWindowToFront(element: mainWindow)
        }
    }

    fileprivate func processNotification(observer: AXObserver, element: AXUIElement, notification: CFString) {
        switch String(notification) {
        case kAXTitleChangedNotification:
            guard let appPID = appPID(for: observer) else {
                return
            }

            if let windowIdx = windows.firstIndex(where: { $0.element == element }) {
                guard let app = NSRunningApplication(processIdentifier: appPID),
                      let updatedWindow = Window(element: element, fallbackApp: app) else {
                    windows.remove(at: windowIdx)
                    reconcileRecentWindowKeys()
                    return
                }

                windows[windowIdx] = updatedWindow
                reconcileRecentWindowKeys()
            } else {
                syncWindowIfNeeded(observer: observer, element: element)
            }

        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            if let windowIdx = windows.firstIndex(where: { $0.element == element }) {
                windows[windowIdx].frame = element.windowFrame
                reconcileRecentWindowKeys()
            } else {
                syncWindowIfNeeded(observer: observer, element: element)
            }

        case kAXWindowCreatedNotification,
             kAXWindowMiniaturizedNotification,
             kAXWindowDeminiaturizedNotification:
            syncWindowIfNeeded(observer: observer, element: element)

        case kAXApplicationActivatedNotification:
            guard let appPID = appPID(for: observer) else {
                return
            }

            syncWindows(for: appPID)
            moveFocusedWindowToFront(for: appPID)

        case kAXFocusedWindowChangedNotification,
             kAXMainWindowChangedNotification:
            guard let appPID = appPID(for: observer) else {
                return
            }

            if moveTrackedWindowToFront(element: element) {
                return
            }

            syncWindows(for: appPID)
            moveFocusedWindowToFront(for: appPID)

        case kAXApplicationHiddenNotification:
            break

        case kAXApplicationShownNotification:
            guard let appPID = appPID(for: observer) else {
                return
            }

            syncWindows(for: appPID)

        case kAXUIElementDestroyedNotification:
            guard let windowIdx = windows.firstIndex(where: { $0.element == element }) else {
                return
            }

            let appPID = windows[windowIdx].appPID
            windows.remove(at: windowIdx)
            syncWindows(for: appPID)

        default:
            return
        }
    }

    private static func getApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    private static func getWindows(for app: NSRunningApplication) -> [Window] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        if app.requiresAXEnhancedUserInterface {
            AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        }

        var result: CFArray?
        guard AXUIElementCopyAttributeValues(axApp, kAXWindowsAttribute as CFString, 0, 100, &result) == .success,
              let axWindows = result as? [AXUIElement] else {
            return []
        }

        var windows: [Window] = []
        for axWindow in axWindows {
            guard let window = Window(element: axWindow, fallbackApp: app) else {
                continue
            }

            // Ensure the window actually belongs to the app we are querying.
            // This prevents Chrome PWAs from returning main Chrome windows and vice versa.
            guard window.appPID == app.processIdentifier else {
                continue
            }

            guard !windows.contains(window) else {
                continue
            }

            windows.append(window)
        }
        return windows
    }

    private static func getInitialWindows(_ apps: [NSRunningApplication]) -> [Window] {
        apps.flatMap(getWindows(for:))
    }

    private static func seedRecentWindowKeys(for windows: [Window]) -> [WindowRecentUseKey] {
        let snapshot = windows.map(WindowIdentityDescriptors.recentUseSnapshotEntry(for:))
        let candidates = getOnScreenWindowCandidates(for: windows)
        return WindowRecentUse.seededKeys(snapshot: snapshot, from: candidates)
    }

    private static func getOnScreenWindowCandidates(for windows: [Window]) -> [WindowRecentUseSeedCandidate] {
        let trackedPIDs = Set(windows.map(\.appPID))
        guard !trackedPIDs.isEmpty,
              let cgWindowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return []
        }

        return cgWindowInfo.compactMap { info in
            guard let ownerPIDValue = info[kCGWindowOwnerPID as String] as? NSNumber,
                  trackedPIDs.contains(ownerPIDValue.int32Value),
                  let layerValue = info[kCGWindowLayer as String] as? NSNumber,
                  layerValue.intValue == 0 else {
                return nil
            }

            let appPID = ownerPIDValue.int32Value
            let title = info[kCGWindowName as String] as? String
            let titleKey = title.map { WindowTitleKey(appPID: appPID, title: $0) }
            let recentUseKey = title.flatMap { title -> WindowRecentUseKey? in
                guard let bounds = getBounds(from: info) else {
                    return nil
                }

                return WindowRecentUseKey(appPID: appPID, title: title, size: bounds.size)
            }

            return WindowRecentUseSeedCandidate(titleKey: titleKey, recentUseKey: recentUseKey)
        }
    }

    private static func getBounds(from info: [String: Any]) -> CGRect? {
        guard let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary else {
            return nil
        }

        var bounds = CGRect.zero
        guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &bounds) else {
            return nil
        }

        return bounds
    }
}
