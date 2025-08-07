//
//  ContentViewModel.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI
import AppKit

class ContentViewModel: ObservableObject {
    var windowModel: Windows = Windows()
    var streamModel: WindowStreams
    var applications: [Application]

    @Published var searchText: String = "" {
        didSet {
            search()
        }
    }
    var items: [SearchItem]

    @Published var selectedIndex = -1 {
        didSet {
            if selectedIndex == -1 {
                selectedItem = nil
                selectedWindowPreview = nil
            } else {
                selectedItem = items[selectedIndex]
                switch selectedItem! {
                case .window(let w):
                    DispatchQueue.main.async {
                        Task {
                            do {
                                self.selectedWindowPreview = try await self.streamModel.getWindowPreview(for: w)
                            } catch let err {
                                print("error: get window preview: \(err)")
                                exit(1)
                            }
                        }
                    }
                case .application:
                    selectedWindowPreview = nil
                }
            }
        }
    }
    var selectedItem: SearchItem?
    @Published var selectedWindowPreview: CGImage?

    init() {
        applications = getInstalledApplications()
        streamModel = WindowStreams(windowModel.windows)
        // Search on empty string to start.
        items = windowModel.search("").map { SearchItem.window($0) }
    }

    private func updateSearchTextAsync(_ text: String) {
        DispatchQueue.main.async {
            self.searchText = text
        }
    }

    private func updateSelectedIndex(_ i: Int) {
        DispatchQueue.main.async {
            self.selectedIndex = i
        }
    }

    // selectPreviousItem circularly selects the previous result
    // (i.e. it goes to last if you select prev of first). If nothing
    // is selected, it starts with last.
    private func selectPreviousItem() {
        let n = items.count
        if selectedIndex == -1 {
            updateSelectedIndex(n - 1)
        } else {
            updateSelectedIndex((selectedIndex + n - 1) % n)
        }
    }

    // selectNextItem circularly selects the next result (i.e. it
    // goes back to first if you select the next of last).
    // If nothing is selected, it starts at 0.
    private func selectNextItem() {
        let n = items.count
        if selectedIndex == -1 {
            updateSelectedIndex(0)
        } else {
            updateSelectedIndex((selectedIndex + 1) % n)
        }
    }

    // toggleSelectedItem activates the window or opens the app.
    func toggleSelectedItem() {
        guard let selectedItem else {
            return
        }
        switch selectedItem {
        case .window(let w):
            Windows.select(w)
        case .application(let app):
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: app.url, configuration: configuration, completionHandler: nil)
        }

        // Perform some cleanup.
        updateSearchTextAsync("")
    }

    // handleKeyPress handles events for special keys.
    func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        switch key.key {
        case .upArrow:
            selectPreviousItem()
            break
        case .downArrow:
            selectNextItem()
            break
        case .escape:
            if !searchText.isEmpty {
                updateSearchTextAsync("")
            } else {
                NSApplication.shared.hide(self)
            }
            break
        case .return:
            toggleSelectedItem()
            break
        case .tab:
            if key.modifiers.contains(.option) {
                NSApplication.shared.hide(self)
            } else {
                selectNextItem()
            }
            break
        default:
            return KeyPress.Result.ignored
        }

        return KeyPress.Result.handled
    }

    // search filters the windows and apps that match the searchText.
    private func search() {
        DispatchQueue.main.async {
            var results: [SearchItem] = self.windowModel.search(self.searchText).map { SearchItem.window($0) }
            if !self.searchText.isEmpty {
                var appResults: [(Int16, Application)] = []
                for app in self.applications {
                    let score = FuzzyCompare(self.searchText.lowercased(), app.name.lowercased())
                    if score > 3 {
                        appResults.append((score, app))
                    }
                }
                appResults.sort(by: { $0.0 > $1.0 })
                results.append(contentsOf: appResults.map { SearchItem.application($0.1) })
            }

            self.items = results
            // Reset selection to top since the search query changed.
            self.selectedIndex = min(0, self.items.count - 1)
        }
    }

    // refresh gets all open windows, clears the search text and the window filter.
    func refresh() {
        windowModel.refreshWindows()
        updateSearchTextAsync("")
        Task {
            do {
                try await streamModel.refresh(windowModel.windows)
                // Trigger index update once streams are refreshed.
                updateSelectedIndex(min(0, items.count - 1))
            } catch let err {
                print("error: refresh streamModel \(err)")
                exit(1)
            }
        }
    }

    // fullRefresh reindexes all windows from scratch.
    func fullRefresh() {
        windowModel.fullRefreshWindows()
        applications = getInstalledApplications()
        // Search on empty string to start.
        updateSearchTextAsync("")
        Task {
            do {
                try await streamModel.refresh(windowModel.windows)
                // Trigger index update once streams are refreshed.
                updateSelectedIndex(min(0, items.count - 1))
            } catch let err {
                print("error: refresh streamModel \(err)")
                exit(1)
            }
        }
    }
}
