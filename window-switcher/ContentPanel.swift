import AppKit
import SwiftUI

class ContentPanel: NSPanel {
    private let closeWindow: () -> Void
    private let windowClient: WindowClient
    private let streamClient: WindowStreamClient

    init(closeWindow: @escaping () -> Void, windowClient: WindowClient, streamClient: WindowStreamClient) {
        self.closeWindow = closeWindow
        self.windowClient = windowClient
        self.streamClient = streamClient
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .titled],
            backing: .buffered,
            defer: true
        )
        
        setupWindow()
        setupView()
    }
    
    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        collectionBehavior = [
            .canJoinAllSpaces,
            .transient,
        ]
    }
    
    private func setupView() {
        let sv = SwitcherView(closeWindow: closeWindow, windowClient: windowClient, streamClient: streamClient)
        let hostingView = NSHostingView(rootView: sv)
        self.contentView = hostingView
        
        hostingView.setFrameSize(CGSize(width: 800, height: 500))
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = (screenFrame.size.width - hostingView.frame.width) / 2 + screenFrame.origin.x
            // Place switcher at top 1/3 of screen.
            let y = screenFrame.size.height / 3 * 2 - hostingView.frame.height / 2 + screenFrame.origin.y
            setFrameOrigin(NSPoint(x: x, y: y))
            setContentSize(hostingView.frame.size)
        }
    }
    
}
