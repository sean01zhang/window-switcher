//
//  WindowImageView.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-06.
//

import SwiftUI

struct WindowImageView: View {
    @Binding var cgImage: CGImage?
    @Binding var appImage: NSImage?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = selectedImage(), let appImage = appImage {
                image
                    .resizable()
                    .scaledToFit()
                Image(nsImage: appImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .offset(x: 5, y: 10)
            } else if let appImage {
                Image(nsImage: appImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            } else {
                RoundedRectangle(cornerRadius: 4).fill(Color.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func selectedImage() -> Image? {
        if let img = cgImage {
            let uiImage = NSImage(cgImage: img, size: .zero)
            return Image(nsImage: uiImage)
        }
        return nil
    }
}
