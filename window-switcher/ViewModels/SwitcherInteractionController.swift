import SwiftUI
import AppKit
import Observation

extension SwitcherView {
    @MainActor
    @Observable
    class InteractionController {
        private let triggerShortcut: TriggerShortcut
        private let quickSwitchEnabled: Bool

        private var isQuickSwitch: Bool = true
        private var selectOnRelease: Bool = false
        @ObservationIgnored private var localModifierMonitor: Any?
        @ObservationIgnored private var globalModifierMonitor: Any?

        init(
            triggerShortcut: TriggerShortcut,
            quickSwitchEnabled: Bool
        ) {
            self.triggerShortcut = triggerShortcut
            self.quickSwitchEnabled = quickSwitchEnabled
        }

        func handleKeyPress(
            _ key: KeyPress,
            selectedItem: SearchItem?,
            searchText: String,
            onCloseWindow: () -> Void,
            onClearSearch: () -> Void,
            onSelectPrevious: () -> Void,
            onSelectNext: () -> Void,
            onEnterSelectedItem: () -> Void,
            onHandleConfiguredNavigation: (KeyPress) -> Bool
        ) -> KeyPress.Result {
            if triggerShortcut.matches(
                key: key.key,
                characters: key.characters,
                modifiers: key.modifiers
            ) && !isQuickSwitch {
                onCloseWindow()
                return .handled
            }

            let didHandleNavigation = onHandleConfiguredNavigation(key)
                || handleBuiltInNavigationKeyPress(
                    key,
                    onSelectPrevious: onSelectPrevious,
                    onSelectNext: onSelectNext
                )

            if didHandleNavigation {
                if isQuickSwitch {
                    selectOnRelease = true
                }
                return .handled
            }

            switch key.key {
            case .escape:
                if !searchText.isEmpty {
                    onClearSearch()
                } else {
                    onCloseWindow()
                }
            case .return:
                onEnterSelectedItem()
            case .tab:
                if !key.modifiers.contains(.option) || isQuickSwitch {
                    onSelectNext()
                } else {
                    return .ignored
                }
            default:
                return .ignored
            }

            return .handled
        }

        func handleBuiltInNavigationKeyPress(
            _ key: KeyPress,
            onSelectPrevious: () -> Void,
            onSelectNext: () -> Void
        ) -> Bool {
            switch key.key {
            case .upArrow:
                onSelectPrevious()
                return true
            case .downArrow:
                onSelectNext()
                return true
            case .tab:
                if !key.modifiers.contains(.option) || isQuickSwitch {
                    onSelectNext()
                    return true
                }
                return false
            default:
                return false
            }
        }

        func installModifierMonitors(
            onModifierFlagsChanged: @escaping (NSEvent.ModifierFlags) -> Void
        ) {
            selectOnRelease = false
            isQuickSwitch = isQuickSwitchActive(for: NSEvent.modifierFlags)

            guard quickSwitchEnabled else {
                return
            }

            if localModifierMonitor == nil {
                localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    onModifierFlagsChanged(event.modifierFlags)
                    return event
                }
            }

            if globalModifierMonitor == nil {
                globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
                    onModifierFlagsChanged(event.modifierFlags)
                }
            }
        }

        func removeModifierMonitors() {
            if let localModifierMonitor {
                NSEvent.removeMonitor(localModifierMonitor)
                self.localModifierMonitor = nil
            }

            if let globalModifierMonitor {
                NSEvent.removeMonitor(globalModifierMonitor)
                self.globalModifierMonitor = nil
            }
        }

        func handleModifierFlagsChanged(
            _ flags: NSEvent.ModifierFlags,
            selectedItem: SearchItem?,
            onEnterItem: (SearchItem) -> Void,
            onCloseWindow: () -> Void
        ) {
            guard quickSwitchEnabled else {
                return
            }

            if !isQuickSwitchActive(for: flags) {
                if selectOnRelease {
                    if let selectedItem {
                        onEnterItem(selectedItem)
                        onCloseWindow()
                    }
                    return
                }

                isQuickSwitch = false
            }
        }

        private func isQuickSwitchActive(for flags: NSEvent.ModifierFlags) -> Bool {
            guard quickSwitchEnabled else {
                return false
            }

            return flags.isSuperset(of: triggerShortcut.modifiers)
        }
    }
}
