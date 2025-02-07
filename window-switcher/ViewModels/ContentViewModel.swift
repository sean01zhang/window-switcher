//
//  ContentViewModel.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI

class ContentViewModel: ObservableObject {
    var windowModel: Windows = Windows()
    var streamModel: WindowStreams
    
    @Published var searchText: String = "" {
        didSet {
            search()
        }
    }
    var windows: [Window]

    @Published var selectedWindowIndex = -1 {
        didSet {
            if selectedWindowIndex == -1 {
                selectedWindow = nil
                selectedWindowPreview = nil
            } else {
                selectedWindow = windows[selectedWindowIndex]
                
                DispatchQueue.main.async {
                    Task {
                        do {
                            self.selectedWindowPreview = try await self.streamModel.getWindowPreview(for: self.windows[self.selectedWindowIndex])
                        } catch let err {
                            print("error: get window preview: \(err)")
                            exit(1)
                        }
                    }
                }
            }
        }
    }
    var selectedWindow: Window?
    @Published var selectedWindowPreview: CGImage?

    init() {
        // Search on empty string to start.
        windows = windowModel.search("")
        streamModel = WindowStreams(windowModel.windows)
    }
    
    private func updateSearchTextAsync(_ text: String) {
        DispatchQueue.main.async {
            self.searchText = text
        }
    }
    
    private func updateSelectedWindowIndex(_ i: Int) {
        DispatchQueue.main.async {
            self.selectedWindowIndex = i
        }
    }
    
    // selectPreviousWindow circularly selects the prev window
    // (i.e. it goes to last if you select prev of first). If nothing
    // is selected, it starts with last.
    private func selectPreviousWindow() {
        let n = windows.count
        if selectedWindowIndex == -1 {
            updateSelectedWindowIndex(n - 1)
        } else {
            updateSelectedWindowIndex((selectedWindowIndex + n - 1) % n)
        }
    }
    
    // selectNextWindow circularly selects the next window (i.e. it
    // goes back to first if you select the next of last).
    // If nothing is selected, it starts at 0.
    private func selectNextWindow() {
        let n = windows.count
        if selectedWindowIndex == -1 {
            updateSelectedWindowIndex(0)
        } else {
            updateSelectedWindowIndex((selectedWindowIndex + 1) % n)
        }
    }
    
    // toogleWindow brings the window to the foreground and switches to it.
    func toggleSelectedWindow() {
        guard let selectedWindow else {
            return
        }
        Windows.select(selectedWindow)
        
        // Perform some cleanup.
        updateSearchTextAsync("")
    }
        
    // handleKeyPress handles events for special keys.
    func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        switch key.key {
        case .upArrow:
            selectPreviousWindow()
            break
        case .downArrow:
            selectNextWindow()
            break
        case .escape:
            if !searchText.isEmpty {
                updateSearchTextAsync("")
            } else {
                NSApplication.shared.hide(self)
            }
            break
        case .return:
            toggleSelectedWindow()
            break
        case .tab:
            if key.modifiers.contains(.option) {
                NSApplication.shared.hide(self)
            } else {
                selectNextWindow()
            }
            break
        default:
            return KeyPress.Result.ignored
        }
        
        return KeyPress.Result.handled
    }
    
    // search filters the windows that match the searchText.
    private func search() {
        DispatchQueue.main.async {
            self.windows = self.windowModel.search(self.searchText)
            
            // Update selection to stay within bounds.
            // Reset selection to top since the search query changed.
            self.selectedWindowIndex = min(0, self.windows.count - 1)
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
                updateSelectedWindowIndex(min(0, windows.count - 1))
            } catch let err {
                print("error: refresh streamModel \(err)")
                exit(1)
            }
        }
    }
    
    // fullRefresh reindexes all windows from scratch.
    func fullRefresh() {
        windowModel.fullRefreshWindows()
        // Search on empty string to start.
        updateSearchTextAsync("")
        Task {
            do {
                try await streamModel.refresh(windowModel.windows)
                // Trigger index update once streams are refreshed.
                updateSelectedWindowIndex(min(0, windows.count - 1))
            } catch let err {
                print("error: refresh streamModel \(err)")
                exit(1)
            }
        }
    }
}
