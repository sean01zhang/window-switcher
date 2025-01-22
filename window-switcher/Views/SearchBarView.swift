//
//  SearchBarView.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    @State private var focusTextField = false
    let searchPrompt: String
    let height: CGFloat = 25
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.secondary)
                .font(Font.system(size: 18))
            TextField(
                searchPrompt, text: $searchText
            )
            .textFieldStyle(.plain)
            .font(Font.system(size: height))
            .background(Color.clear)
            .frame(height: height)
            .focused($isFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .padding()
    }
}
