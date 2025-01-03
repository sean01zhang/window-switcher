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
                            HStack {
                                Text(window.fqn())
                                    // Yes you need maxHeight AND maxWidth infinity to
                                    // make the text box extend all the way.
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                    .font(.system(size: 14))
                                    .foregroundStyle(viewModel.isSelected(window) ? Color.white : Color.black)
                            }
                            .contentShape(Rectangle())
                                .padding(4)
                                .padding(.horizontal, 8)
                                .onTapGesture {
                                    if viewModel.isSelected(window) {
                                        viewModel.toggleSelectedWindow()
                                    } else {
                                        viewModel.selectWindow(window)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 8).fill(
                                        viewModel.isSelected(window) ?
                                        Color.accentColor : Color.clear
                                    )
                                )
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
        .onChange(of: viewModel.searchText, initial: true) { oldValue, newValue in
            viewModel.search()
        }
        .onKeyPress(.upArrow) {
            viewModel.selectPreviousWindow()
            return KeyPress.Result.handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNextWindow()
            return KeyPress.Result.handled
        }
        .onKeyPress(.return) {
            viewModel.toggleSelectedWindow()
            return KeyPress.Result.handled
        }
        .onKeyPress(.escape) {
            if !viewModel.searchText.isEmpty {
                viewModel.updateSearchTextAsync("")
            } else {
                // Close window
                NSApplication.shared.hide(self)
            }
            
            return KeyPress.Result.handled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            viewModel.refresh()
        }
    }
}
