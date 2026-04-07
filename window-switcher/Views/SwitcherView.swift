import SwiftUI

struct VisualEffect: NSViewRepresentable {
   func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
   func updateNSView(_ nsView: NSView, context: Context) { }
}

struct SwitcherView: View {
    let closeWindow: () -> Void
    let windowClient: WindowClient
    let streamClient: WindowStreamClient
    let installedApplicationsClient: InstalledApplicationsClient
    let workspaceClient: any WorkspaceClient
    let triggerShortcut: TriggerShortcut
    let quickSwitchEnabled: Bool
    let navigation: NavigationConfig
    let resultListItem: ResultListItemConfig
    @State private var viewModel: ViewModel
    @State private var interactionController: InteractionController

    init(
        closeWindow: @escaping () -> Void,
        windowClient: WindowClient,
        streamClient: WindowStreamClient,
        installedApplicationsClient: InstalledApplicationsClient,
        workspaceClient: any WorkspaceClient,
        triggerShortcut: TriggerShortcut,
        quickSwitchEnabled: Bool,
        navigation: NavigationConfig,
        resultListItem: ResultListItemConfig
    ) {
        self.closeWindow = closeWindow
        self.windowClient = windowClient
        self.streamClient = streamClient
        self.installedApplicationsClient = installedApplicationsClient
        self.workspaceClient = workspaceClient
        self.triggerShortcut = triggerShortcut
        self.quickSwitchEnabled = quickSwitchEnabled
        self.navigation = navigation
        self.resultListItem = resultListItem
        _viewModel = State(initialValue: ViewModel(
            windowClient: windowClient,
            streamClient: streamClient,
            installedApplicationsClient: installedApplicationsClient,
            workspaceClient: workspaceClient
        ))
        _interactionController = State(initialValue: InteractionController(
            triggerShortcut: triggerShortcut,
            quickSwitchEnabled: quickSwitchEnabled
        ))
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
        .onAppear {
            interactionController.installModifierMonitors(
                onModifierFlagsChanged: handleModifierFlagsChanged
            )
        }
        .onDisappear {
            interactionController.removeModifierMonitors()
        }
        .onKeyPress { key in
            interactionController.handleKeyPress(
                key,
                selectedItem: viewModel.selectedItem,
                searchText: viewModel.searchText,
                onCloseWindow: closeWindow,
                onClearSearch: { viewModel.searchText = "" },
                onSelectPrevious: viewModel.selectPrev,
                onSelectNext: viewModel.selectNext,
                onEnterSelectedItem: enterSelectedItem,
                onHandleConfiguredNavigation: handleConfiguredNavigationKeyPress
            )
        }
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
        interactionController.handleBuiltInNavigationKeyPress(
            key,
            onSelectPrevious: viewModel.selectPrev,
            onSelectNext: viewModel.selectNext
        )
    }

    private func enterSelectedItem() {
        guard let item = viewModel.selectedItem else {
            return
        }

        viewModel.enterItem(item)
        closeWindow()
    }

    private func handleModifierFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        interactionController.handleModifierFlagsChanged(
            flags,
            selectedItem: viewModel.selectedItem,
            onEnterItem: viewModel.enterItem,
            onCloseWindow: closeWindow
        )
    }
}
