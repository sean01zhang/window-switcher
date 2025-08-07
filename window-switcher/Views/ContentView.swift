//
//  ContentView.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI

struct VisualEffect: NSViewRepresentable {
   func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
   func updateNSView(_ nsView: NSView, context: Context) { }
}

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    
    var body: some View {
        VSplitView {
            HSplitView {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.items.indices, id: \.self) { i in
                                ResultListItemView(item: viewModel.items[i], isSelected: i == viewModel.selectedIndex)
                                    .onTapGesture {
                                        if i == viewModel.selectedIndex {
                                            viewModel.toggleSelectedItem()
                                        } else {
                                            viewModel.selectedIndex = i
                                        }
                                    }
                                    .focusable()
                                    .focusEffectDisabled()
                            }
                        }
                        .onChange(of: viewModel.selectedIndex, initial: true) { _, new in
                            guard new != -1 else { return }
                            withAnimation {
                                proxy.scrollTo(new, anchor: .center)
                            }
                        }
                    }
                }
                .padding()
                ZStack {
                    WindowImageView(cgImage: $viewModel.selectedWindowPreview)
                }.padding()
            }
            SearchBarView(searchText: $viewModel.searchText, searchPrompt: "Search Windows or Apps")
        }
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 16)))
        .onKeyPress() { key in
            return viewModel.handleKeyPress(key)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .restartWindowSwitcher)) { _ in
            #if DEBUG
                print("DEBUG: Restarting window switcher...")
            #endif
            viewModel.fullRefresh()
        }
    }
}
