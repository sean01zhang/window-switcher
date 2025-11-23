import SwiftUI

struct VisualEffect: NSViewRepresentable {
   func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
   func updateNSView(_ nsView: NSView, context: Context) { }
}

struct SwitcherView: View {
    let closeWindow: () -> Void
    let windowClient: WindowClient
    let streamClient: WindowStreamClient
    @State private var viewModel: ViewModel

    init(closeWindow: @escaping () -> Void, windowClient: WindowClient, streamClient: WindowStreamClient) {
        self.closeWindow = closeWindow
        self.windowClient = windowClient
        self.streamClient = streamClient
        _viewModel = State(initialValue: ViewModel(windowClient: windowClient, streamClient: streamClient))
    }
    
    var body: some View {
        VStack {
            HSplitView {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.searchItems, id: \.self) { item in
                                ResultListItemView(item: item, isSelected: item == viewModel.selectedItem)
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
                        }
                        .onChange(of: viewModel.selectedItem, initial: true) { _, newItem in
                            guard newItem != nil else { return }
                            withAnimation {
                                proxy.scrollTo(newItem, anchor: .center)
                            }
                        }
                    }
                }
                .padding(.trailing)
                ZStack {
                    WindowImageView(cgImage: $viewModel.selectedItemPreview)
                }.padding(.leading)
            }
        }
        .padding(20)
        .background(
            Group {
                if #available(macOS 26.0, *) {
                    Color.clear.glassEffect(in: RoundedRectangle(cornerRadius: 32))
                } else {
                    VisualEffect().clipShape(RoundedRectangle(cornerRadius: 32))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 32))
        // Close window when switcher view loses focus.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            closeWindow()
        }
        // Floating, shorter, fully-rounded search bar with shadow at bottom
        .overlay(alignment: .bottom) {
            SearchBarView(searchText: $viewModel.searchText, searchPrompt: "Search Windows or Apps")
                .background(
                    Group {
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
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .onKeyPress() { key in
            switch key.key {
            case .upArrow:
                viewModel.selectPrev()
                break
            case .downArrow:
                viewModel.selectNext()
                break
            case .escape:
                if !viewModel.searchText.isEmpty {
                    viewModel.searchText = ""
                } else {
                    closeWindow()
                }
                break
            case .return:
                if let item = viewModel.selectedItem {
                    viewModel.enterItem(item)
                    closeWindow()
                }
                break
            case .tab:
                if key.modifiers.contains(.option) {
                    closeWindow()
                } else {
                    viewModel.selectNext()
                }
                break
            default:
                return KeyPress.Result.ignored
            }

            return KeyPress.Result.handled
        }
    }
}
