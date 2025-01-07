//
//  WindowImageView.swift
//  window-switcher
//
//  Created by Sean Zhang on 2025-01-06.
//

import SwiftUI

struct WindowImageView: View {
//    @Binding var cgImage: CGImage?
    @Binding var windowStream: WindowStream?
    
    var body: some View {
        HStack {
            VStack {
                Group {
                    if let image = selectedImage() {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(alignment: .center)
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray)
                    }
                }
                .frame(alignment: .center)
            }
        }
    }
    
    func selectedImage() -> Image? {
        if let img = windowStream?.capturedImage {
            let uiImage = NSImage(cgImage: img, size: .zero)
            return Image(nsImage: uiImage)
        }
        
        return nil
    }
}
