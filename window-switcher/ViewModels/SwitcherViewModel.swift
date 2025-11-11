//
//  ContentViewModel.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI
import AppKit
import Observation

extension SwitcherView {
    @MainActor
    @Observable
    class ViewModel {
        // State
        var searchItems: [SearchItem] = []
        var searchText: String = "" {
            // Hook to call search function when searchText is updated.
            didSet {
                search()
            }
        }
        var selectedItem: SearchItem? = nil {
            didSet {
                guard selectedItem != nil else {
                    return
                }
                switch selectedItem! {
                case .window(let w):
                    Task {
                        do {
                            self.selectedItemPreview = try await self.streamClient.getWindowPreview(for: w)
                        } catch let err {
                            print("error: get window preview: \(err)")
                        }
                    }
                case .application:
                    selectedItemPreview = nil
                }
            }
        }
        var selectedItemPreview: CGImage?
        
        // Utilities (injected)
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
            // Perform a search on relevant windows first.
            var resultScores: [(Int16, SearchItem)] = Windows.search(
                self.searchText,
                self.windowClient.getWindows()
            ).map { ( $0.0, SearchItem.window($0.1) ) }
                
            // Search for relevant applications next, and append to scores.
            // This is appended because open windows should take precedence over
            // applications.
            if !self.searchText.isEmpty {
                var appResults: [(Int16, Application)] = []
                for app in getInstalledApplications() {
                    let score = FuzzyCompare(self.searchText.lowercased(), app.name.lowercased())
                    if score > 3 {
                        appResults.append((score, app))
                    }
                }
                resultScores.append(contentsOf: appResults.map { ( $0.0, SearchItem.application($0.1))})
            }
            
            // Sort by scores (first item in tuple), then get ordered searchitems.
            resultScores.sort(by: { $0.0 > $1.0 })
            let results = resultScores.map(\.1)
            
            searchItems = results
            selectedItem = results.first
        }
    }
}
