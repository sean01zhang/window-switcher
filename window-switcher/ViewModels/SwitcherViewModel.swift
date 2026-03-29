import SwiftUI
import AppKit
import Observation

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

                guard let selectedItem else {
                    selectedItemPreview = nil
                    return
                }

                switch selectedItem {
                case .window(let w):
                    selectedItemPreview = nil
                    previewTask = Task { [weak self] in
                        guard let self else {
                            return
                        }

                        do {
                            let preview = try await self.streamClient.getWindowPreview(
                                for: w,
                                among: self.windowClient.getWindows()
                            )
                            guard !Task.isCancelled, self.selectedItem == .window(w) else {
                                return
                            }
                            self.selectedItemPreview = preview
                        } catch is CancellationError {
                            return
                        } catch {
                            print("error: get window preview: \(error)")
                        }
                    }
                case .application:
                    selectedItemPreview = nil
                    previewTask = nil
                }
            }
        }
        var selectedItemPreview: CGImage?
        
        // Utilities
        let windowClient: WindowClient
        let streamClient: WindowStreamClient

        init(windowClient: WindowClient, streamClient: WindowStreamClient) {
            self.windowClient = windowClient
            self.streamClient = streamClient
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
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: app.url, configuration: configuration, completionHandler: nil)
            }

            // Perform some cleanup.
            searchText = ""
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
            let windowResults = Windows.search(
                query,
                windowClient.getWindows()
            ).map { ( $0.0, SearchItem.window($0.1) ) }

            applySearchResults(windowResults)

            guard !query.isEmpty else {
                return
            }

            applicationSearchTask = Task { [weak self] in
                guard let self else {
                    return
                }

                let appResults = await ApplicationIndex.shared.search(query)
                guard !Task.isCancelled, self.searchText == query else {
                    return
                }

                self.applySearchResults(
                    windowResults + appResults.map { ( $0.0, SearchItem.application($0.1) ) }
                )
            }
        }

        private func applySearchResults(_ resultScores: [(Int16, SearchItem)]) {
            let results = resultScores
                .sorted(by: Self.compareSearchResults)
                .map(\.1)

            searchItems = results
            selectedItem = results.first
        }

        private static func compareSearchResults(
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
                return false
            }
        }
    }
}
