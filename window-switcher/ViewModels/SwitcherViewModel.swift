import SwiftUI
import AppKit
import Observation

enum SwitcherSearchMode {
    case blankQuery
    case searchQuery
}

enum SwitcherSearchResults {
    static func orderedItems(
        from resultScores: [(Int16, SearchItem)],
        mode: SwitcherSearchMode
    ) -> [SearchItem] {
        switch mode {
        case .blankQuery:
            return resultScores.map(\.1)
        case .searchQuery:
            return resultScores
                .sorted(by: compareSearchResults)
                .map(\.1)
        }
    }

    static func initialSelectionIndex(
        resultCount: Int,
        mode: SwitcherSearchMode
    ) -> Int? {
        guard resultCount > 0 else {
            return nil
        }
        return 0
    }

    static func compareSearchResults(
        lhs: (Int16, SearchItem),
        rhs: (Int16, SearchItem)
    ) -> Bool {
        if lhs.0 != rhs.0 {
            return lhs.0 > rhs.0
        }

        switch (lhs.1, rhs.1) {
        case (.window, .application):
            return true
        case (.application, .window):
            return false
        default:
            return lhs.1.sortLabel < rhs.1.sortLabel
        }
    }
}

extension SwitcherView {
    @MainActor
    @Observable
    class ViewModel {
        // State
        var searchItems: [SearchItem] = []
        private var applicationSearchTask: Task<Void, Never>?
        private var previewTask: Task<Void, Never>?
        var searchText: String = "" {
            // Hook to call search function when searchText is updated.
            didSet {
                search()
            }
        }
        var selectedItem: SearchItem? = nil {
            didSet {
                previewTask?.cancel()
                ensurePreviewLoaded(for: selectedItem)
            }
        }

        // Icon caches keyed by PID (windows) and URL path (apps).
        // Valid for the lifetime of the ViewModel (one switcher session),
        // since PIDs and app bundles don't change mid-session.
        @ObservationIgnored private var windowIconCache: [Int32: NSImage] = [:]
        @ObservationIgnored private var appIconCache: [String: NSImage] = [:]

        // Utilities
        let windowClient: WindowClient
        let streamClient: WindowStreamClient
        let installedApplicationsClient: InstalledApplicationsClient
        let workspaceClient: any WorkspaceClient

        init(
            windowClient: WindowClient,
            streamClient: WindowStreamClient,
            installedApplicationsClient: InstalledApplicationsClient,
            workspaceClient: any WorkspaceClient
        ) {
            self.windowClient = windowClient
            self.streamClient = streamClient
            self.installedApplicationsClient = installedApplicationsClient
            self.workspaceClient = workspaceClient
            // Seed initial results
            search()
        }

        // Handlers
        /// Callback for when an a search item is switched to.
        func enterItem(_ item: SearchItem) {
            switch item {
            case .window(let w):
                windowClient.focusWindow(w)
            case .application(let app):
                workspaceClient.openApplication(app.url)
            }

            // Perform some cleanup.
            searchText = ""
        }

        /// Returns the cached app icon for a search item, fetching and caching on first access.
        func icon(for item: SearchItem) -> NSImage {
            switch item {
            case .window(let w):
                if let cached = windowIconCache[w.appPID] {
                    return cached
                }
                let img = workspaceClient.runningApplicationIcon(processIdentifier: w.appPID)
                    ?? NSImage(named: NSImage.applicationIconName)
                    ?? NSImage()
                windowIconCache[w.appPID] = img
                return img
            case .application(let app):
                let path = app.url.path
                if let cached = appIconCache[path] {
                    return cached
                }
                let img = workspaceClient.iconForFile(path)
                appIconCache[path] = img
                return img
            }
        }

        func preview(for item: SearchItem?) -> CGImage? {
            guard case .window(let window) = item else {
                return nil
            }

            return streamClient.cachedWindowPreview(for: window)
        }

        private func ensurePreviewLoaded(for item: SearchItem?) {
            guard case .window(let window) = item else {
                previewTask = nil
                return
            }

            guard streamClient.cachedWindowPreview(for: window) == nil else {
                previewTask = nil
                return
            }

            previewTask = Task { [weak self] in
                guard let self else {
                    return
                }

                do {
                    _ = try await self.streamClient.getWindowPreview(
                        for: window,
                        among: self.windowClient.getWindows()
                    )
                    guard !Task.isCancelled else {
                        return
                    }
                } catch is CancellationError {
                    return
                } catch {
                    print("error: get window preview: \(error)")
                }
            }
        }

        private func curSelectedItemIndex() -> Int? {
            guard let selectedItem, let index = searchItems.firstIndex(of: selectedItem) else {
                return nil
            }
            return index
        }

        /// Handler when the user wants to select the previous item in the list.
        func selectPrev() {
            // Get index of current selected item. If it doesn't exist, this function no-ops.
            guard let currentIndex = curSelectedItemIndex(), !searchItems.isEmpty else {
                return
            }

            // Set selected item to previous, with circular wraparound (if it's the 0th item)
            let newIndex = (currentIndex - 1 + searchItems.count) % searchItems.count
            selectedItem = searchItems[newIndex]
        }

        /// Handler when the user wants to select the next item in the list.
        func selectNext() {
            // Get index of current selected item. If it doesn't exist, no-op.
            guard let currentIndex = curSelectedItemIndex(), !searchItems.isEmpty else {
                return
            }

            let newIndex = (currentIndex + 1) % searchItems.count
            selectedItem = searchItems[newIndex]
        }

        /// Gets the most relevant results based on the search text.
        private func search() {
            applicationSearchTask?.cancel()

            let query = searchText
            if query.isEmpty {
                let windowResults = windowClient.getWindowsByRecentUse()
                    .map { (Int16(0), SearchItem.window($0)) }
                applySearchResults(windowResults, mode: .blankQuery)
                return
            }

            let windowResults = WindowSearch.search(query, in: windowClient.getWindows())
                .map { ( $0.0, SearchItem.window($0.1) ) }

            applySearchResults(windowResults, mode: .searchQuery)

            applicationSearchTask = Task { [weak self] in
                guard let self else {
                    return
                }

                let appResults = await installedApplicationsClient.search(query)
                guard !Task.isCancelled, self.searchText == query else {
                    return
                }

                self.applySearchResults(
                    windowResults + appResults.map { ( $0.0, SearchItem.application($0.1) ) },
                    mode: .searchQuery
                )
            }
        }

        private func applySearchResults(
            _ resultScores: [(Int16, SearchItem)],
            mode: SwitcherSearchMode
        ) {
            let results = SwitcherSearchResults.orderedItems(from: resultScores, mode: mode)
            searchItems = results

            if let selectedIndex = SwitcherSearchResults.initialSelectionIndex(
                resultCount: results.count,
                mode: mode
            ) {
                selectedItem = results[selectedIndex]
            } else {
                selectedItem = nil
            }
        }
    }
}
