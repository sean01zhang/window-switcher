import SwiftUI

struct VisualEffect: NSViewRepresentable {
   func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
   func updateNSView(_ nsView: NSView, context: Context) { }
}

struct SwitcherView: View {
    let closeWindow: () -> Void
    let windowClient: WindowClient
    let streamClient: WindowStreamClient
    let triggerShortcut: TriggerShortcut
    let navigation: NavigationConfig
    let resultListItem: ResultListItemConfig
    @State private var viewModel: ViewModel
    @State private var isQuickSwitch: Bool = true
    @State private var selectOnRelease: Bool = false
    @State private var localModifierMonitor: Any?
    @State private var globalModifierMonitor: Any?

    init(
        closeWindow: @escaping () -> Void,
        windowClient: WindowClient,
        streamClient: WindowStreamClient,
        triggerShortcut: TriggerShortcut,
        navigation: NavigationConfig,
        resultListItem: ResultListItemConfig
    ) {
        self.closeWindow = closeWindow
        self.windowClient = windowClient
        self.streamClient = streamClient
        self.triggerShortcut = triggerShortcut
        self.navigation = navigation
        self.resultListItem = resultListItem
        _viewModel = State(initialValue: ViewModel(windowClient: windowClient, streamClient: streamClient))
    }
    
    var body: some View {
        VStack {
            contentView
        }
        .padding(20)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        // Close window when switcher view loses focus.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            closeWindow()
        }
        // Floating, shorter, fully-rounded search bar with shadow at bottom
        .overlay(alignment: .bottom) {
            searchBarOverlay
        }
        .onAppear(perform: installModifierMonitors)
        .onDisappear(perform: removeModifierMonitors)
        .onKeyPress(action: handleKeyPress)
    }

    private var contentView: some View {
        HSplitView {
            resultsListView
                .padding(.trailing)
            ZStack {
                WindowImageView(
                    cgImage: viewModel.preview(for: viewModel.selectedItem),
                    appImage: viewModel.selectedItem.map(viewModel.icon(for:))
                )
            }
            .padding(.leading)
        }
    }

    private var resultsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.searchItems, id: \.self) { item in
                        rowView(for: item)
                    }
                }
                .onChange(of: viewModel.selectedItem, initial: true) { _, newItem in
                    guard newItem != nil else { return }
                    withAnimation {
                        proxy.scrollTo(newItem, anchor: .center)
                    }
                }
            }
        }
    }

    private func rowView(for item: SearchItem) -> some View {
        ResultListItemView(
            item: item,
            config: resultListItem,
            isSelected: item == viewModel.selectedItem,
            icon: viewModel.icon(for: item)
        )
            .onTapGesture {
                if item == viewModel.selectedItem {
                    viewModel.enterItem(item)
                    closeWindow()
                } else {
                    viewModel.selectedItem = item
                }
            }
            .focusable()
            .focusEffectDisabled()
    }

    @ViewBuilder
    private var backgroundView: some View {
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(in: RoundedRectangle(cornerRadius: 32))
        } else {
            VisualEffect().clipShape(RoundedRectangle(cornerRadius: 32))
        }
    }

    private var searchBarOverlay: some View {
        SearchBarView(searchText: $viewModel.searchText, searchPrompt: "Search Windows or Apps")
            .background(searchBarBackground)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }

    @ViewBuilder
    private var searchBarBackground: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect()
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
        } else {
            Capsule()
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
        }
    }

    private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        if triggerShortcut.matches(
            key: key.key,
            characters: key.characters,
            modifiers: key.modifiers
        ) && !isQuickSwitch {
            closeWindow()
            return .handled
        }

        let didHandleNavigation = handleConfiguredNavigationKeyPress(key)
            || handleBuiltInNavigationKeyPress(key)

        if didHandleNavigation {
            // If a key press is handled and we haven't let go of hotkey,
            // then we will enter item on release of hotkey.
            if isQuickSwitch {
                selectOnRelease = true
            }
            return .handled
        }

        switch key.key {
        case .escape:
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
            } else {
                closeWindow()
            }
        case .return:
            enterSelectedItem()
        case .tab:
            if !key.modifiers.contains(.option) || isQuickSwitch {
                viewModel.selectNext()
            }
        default:
            return .ignored
        }

        return .handled
    }

    private func handleConfiguredNavigationKeyPress(_ key: KeyPress) -> Bool {
        if matchesAnyShortcut(navigation.previous, keyPress: key) {
            viewModel.selectPrev()
            return true
        }

        if matchesAnyShortcut(navigation.next, keyPress: key) {
            viewModel.selectNext()
            return true
        }

        if matchesAnyShortcut(navigation.enterSelection, keyPress: key) {
            enterSelectedItem()
            return true
        }

        return false
    }

    private func matchesAnyShortcut(_ shortcuts: [TriggerShortcut], keyPress: KeyPress) -> Bool {
        shortcuts.contains {
            $0.matches(
                key: keyPress.key,
                characters: keyPress.characters,
                modifiers: keyPress.modifiers
            )
        }
    }

    private func handleBuiltInNavigationKeyPress(_ key: KeyPress) -> Bool {
        switch key.key {
        case .upArrow:
            viewModel.selectPrev()
            return true
        case .downArrow:
            viewModel.selectNext()
            return true
        case .tab:
            if !key.modifiers.contains(.option) || isQuickSwitch {
                viewModel.selectNext()
                return true
            }
            return false
        default:
            return false
        }
    }

    private func enterSelectedItem() {
        guard let item = viewModel.selectedItem else {
            return
        }

        viewModel.enterItem(item)
        closeWindow()
    }

    private func installModifierMonitors() {
        isQuickSwitch = areQuickSwitchModifiersPressed(NSEvent.modifierFlags)

        if localModifierMonitor == nil {
            localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                handleModifierFlagsChanged(event.modifierFlags)
                return event
            }
        }

        if globalModifierMonitor == nil {
            globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
                handleModifierFlagsChanged(event.modifierFlags)
            }
        }
    }

    private func removeModifierMonitors() {
        if let localModifierMonitor {
            NSEvent.removeMonitor(localModifierMonitor)
            self.localModifierMonitor = nil
        }

        if let globalModifierMonitor {
            NSEvent.removeMonitor(globalModifierMonitor)
            self.globalModifierMonitor = nil
        }
    }

    private func handleModifierFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        if !areQuickSwitchModifiersPressed(flags) {
            if selectOnRelease {
                if let item = viewModel.selectedItem {
                    viewModel.enterItem(item)
                    closeWindow()
                }
                return
            }
            isQuickSwitch = false
        }
    }

    private func areQuickSwitchModifiersPressed(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.isSuperset(of: triggerShortcut.modifiers)
    }
}
