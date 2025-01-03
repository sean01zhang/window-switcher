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
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.windows, id: \.id) { window in
                            WindowListItemView(window: window, isSelected: viewModel.isSelected(window))
                                .onTapGesture {
                                    if viewModel.isSelected(window) {
                                        viewModel.toggleSelectedWindow()
                                    } else {
                                        viewModel.selectWindow(window)
                                    }
                                }
                                .onChange(of: viewModel.selectedWindowIndex, initial: true) { oldIndex, index in
                                    guard index >= 0 else { return }
                                    withAnimation {
                                        proxy.scrollTo(viewModel.windows[index].id, anchor: .center)
                                    }
                                }
                                .focusable()
                                .focusEffectDisabled()
                        }
                    }
                }
                .padding(.horizontal).padding(.top)
            }
            Divider()
            SearchBarView(searchText: $viewModel.searchText, searchPrompt: "Search Windows")
                .padding(.bottom).padding(.horizontal).padding(.top, 5)
        }
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 16)))
        .onKeyPress() { key in
            return viewModel.handleKeyPress(key)
        }
        .onChange(of: viewModel.searchText, initial: true) { oldValue, newValue in
            viewModel.search()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            viewModel.refresh()
        }
    }
}
