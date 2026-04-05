import AppKit
import SwiftUI

struct WindowImageView: View {
    let cgImage: CGImage?
    let selectedItem: SearchItem?
    let appImage: NSImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let previewImage, let appImage {
                previewImage
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

    private var previewImage: Image? {
        guard let cgImage else {
            return nil
        }

        return Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
    }

}
