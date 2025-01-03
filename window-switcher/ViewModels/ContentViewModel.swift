//
//  ContentViewModel.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI

class ContentViewModel: ObservableObject {
    var windowModel: Windows = Windows()
    
    @Published var searchText: String = ""
    var windows: [Window]
    
    @Published var selectedWindow: Window? = nil
    var selectedWindowIndex = -1
    
    init() {
        // Search on empty string to start.
        windows = windowModel.search("")
    }
    
    private func updateSelectedWindowAsync(_ window: Window) {
        DispatchQueue.main.async {
            self.selectedWindow = window
        }
    }
    
    private func updateSearchTextAsync(_ text: String) {
        DispatchQueue.main.async {
            self.searchText = text
            self.windows = self.windowModel.search(text)
        }
    }
    
    // selectPreviousWindow circularly selects the prev window
    // (i.e. it goes to last if you select prev of first). If nothing
    // is selected, it starts with last.
    private func selectPreviousWindow() {
        let n = windows.count
        if selectedWindowIndex == -1 {
            selectedWindowIndex = n - 1
        } else {
            selectedWindowIndex = (selectedWindowIndex + n - 1) % n
        }
        updateSelectedWindowAsync(windows[selectedWindowIndex])
    }
    
    // selectNextWindow circularly selects the next window (i.e. it
    // goes back to first if you select the next of last).
    // If nothing is selected, it starts at 0.
    private func selectNextWindow() {
        let n = windows.count
        if selectedWindowIndex == -1 {
            selectedWindowIndex = 0
        } else {
            selectedWindowIndex = (selectedWindowIndex + 1) % n
        }
        updateSelectedWindowAsync(windows[selectedWindowIndex])
    }
    
    // selectWindow sets the currently selected window to the window provided.
    func selectWindow(_ window: Window) {
        for i in windows.indices where windows[i].id == window.id {
            selectedWindowIndex = i
        }
        updateSelectedWindowAsync(windows[selectedWindowIndex])
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
        default:
            return KeyPress.Result.ignored
        }
        
        return KeyPress.Result.handled
    }
    
    // isSelected returns true if the window provided is selected.
    func isSelected(_ window: Window) -> Bool {
        guard let selectedWindow else {
            return false
        }
        return selectedWindow.id == window.id
    }
    
    // search filters the windows that match the searchText.
    func search() {
        windows = windowModel.search(searchText)
        
        // Update selection to stay within bounds.
        selectedWindowIndex = min(windows.count - 1, max(selectedWindowIndex, 0))
        guard selectedWindowIndex >= 0 else {
            selectedWindow = nil
            return
        }
        updateSelectedWindowAsync(windows[selectedWindowIndex])
    }
   
    // refresh gets all open windows, clears the search text and the window filter.
    func refresh() {
        windowModel.refreshWindows()
        updateSearchTextAsync("")
        search()
    }
}
