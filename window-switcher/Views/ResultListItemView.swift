//
//  ResultListItemView.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import SwiftUI
import AppKit

struct ResultListItemView: View {
    @Environment(\.colorScheme) var colorScheme  // Get the system color scheme
    let item: SearchItem
    let isSelected: Bool
    let fontSize: CGFloat = 14

    func textColorForAccentColor() -> Color {
        // Calculate luminance of the accent color
        let accentColor = NSColor(Color.accentColor).usingColorSpace(.sRGB)!
        let luminance = (0.299 * accentColor.redComponent) + (0.587 * accentColor.greenComponent) + (0.114 * accentColor.blueComponent)

        // Determine contrast based on luminance
        if luminance < 0.5 {
            // Dark background, use light text
            return .white
        } else {
            // Light background, use dark text
            return .black
        }
    }

    private func text() -> String {
        switch item {
        case .window(let w):
            return w.fqn()
        case .application(let app):
            return "Open App: \(app.name)"
        }
    }

    var body: some View {
        HStack {
            Text(text())
                // Yes you need maxHeight AND maxWidth infinity to
                // make the text box extend all the way.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .font(.system(size: fontSize))
                .foregroundStyle(isSelected ? textColorForAccentColor() : Color.primary)
        }
        .contentShape(Rectangle())
            .padding(4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(
                    isSelected ? Color.accentColor : Color.clear
                )
            )
    }
}
