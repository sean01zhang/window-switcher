import AppKit

private func getAttributeValue(
    _ attribute: CFString,
    from element: AXUIElement
) -> CFTypeRef? {
    var valueRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success else {
        return nil
    }

    return valueRef
}

private func getWindowName(element: AXUIElement) -> String? {
    guard let titleRef = getAttributeValue(kAXTitleAttribute as CFString, from: element),
          let title = titleRef as? String else {
        return nil
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedTitle.isEmpty ? nil : trimmedTitle
}

private func getWindowAttribute(
    _ attribute: CFString,
    from element: AXUIElement
) -> AXUIElement? {
    guard let valueRef = getAttributeValue(attribute, from: element) else {
        return nil
    }

    // Ensure the CFTypeRef is actually an AXUIElement before bridging.
    if CFGetTypeID(valueRef) == AXUIElementGetTypeID() {
        // Safe to force-cast after verifying type ID.
        return (valueRef as! AXUIElement)
    } else {
        return nil
    }
}

private func getRole(element: AXUIElement) -> String? {
    guard let roleRef = getAttributeValue(kAXRoleAttribute as CFString, from: element),
          let role = roleRef as? String else {
        return nil
    }

    return role
}

private func isWindowElement(_ element: AXUIElement) -> Bool {
    getRole(element: element) == kAXWindowRole as String
}

private func makeWindow(
    element: AXUIElement,
    app: NSRunningApplication
) -> Window? {
    guard isWindowElement(element),
          let title = getWindowName(element: element) else {
        return nil
    }

    return Window(
        id: element.hashValue,
        appName: app.localizedName ?? "Unknown",
        appPID: app.processIdentifier,
        name: title,
        frame: getWindowFrame(element: element),
        element: element
    )
}

private func getWindowFrame(element: AXUIElement) -> CGRect? {
    var positionRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
          let positionRef,
          CFGetTypeID(positionRef) == AXValueGetTypeID() else {
        return nil
    }
    let position = positionRef as! AXValue
    guard AXValueGetType(position) == .cgPoint else {
        return nil
    }

    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
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
                queue: .main
            ) { [weak self] notification in
                self?.handleWorkspaceLaunch(notification)
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
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

        let pid = app.processIdentifier
        syncWindows(for: pid)
        startObserving(apps: [app])

        // Newly launched apps may not have their accessibility server ready yet,
        // causing observer registration to fail silently. Retry after a short
        // delay to pick up the app once it finishes launching.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.syncWindows(for: pid)
            if self.applicationObservers[pid] == nil {
                if let freshApp = NSRunningApplication(processIdentifier: pid),
                   freshApp.activationPolicy == .regular {
                    self.startObserving(apps: [freshApp])
                }
            }
        }
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
        guard isWindowElement(element),
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

        if let focusedWindow = getWindowAttribute(kAXFocusedWindowAttribute as CFString, from: appElement),
           moveTrackedWindowToFront(element: focusedWindow) {
            return
        }

        if let mainWindow = getWindowAttribute(kAXMainWindowAttribute as CFString, from: appElement) {
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
                      let updatedWindow = makeWindow(element: element, app: app) else {
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
                windows[windowIdx].frame = getWindowFrame(element: element)
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
            guard let appPID = appPID(for: observer) else {
                return
            }

            removeWindows(for: appPID)

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

        var result: CFArray?
        guard AXUIElementCopyAttributeValues(axApp, kAXWindowsAttribute as CFString, 0, 100, &result) == .success,
              let axWindows = result as? [AXUIElement] else {
            return []
        }

        var windows: [Window] = []
        for axWindow in axWindows {
            guard let window = makeWindow(element: axWindow, app: app),
                  !windows.contains(window) else {
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
