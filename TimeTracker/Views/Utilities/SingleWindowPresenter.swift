import SwiftUI
import AppKit

@MainActor
enum SingleWindowPresenter {
    private static var windows: [String: NSWindow] = [:]

    static func show<Content: View>(
        id: String,
        title: String,
        size: NSSize,
        minSize: NSSize,
        @ViewBuilder content: () -> Content
    ) {
        if let existing = windows[id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: content())
        hostingView.frame = NSRect(origin: .zero, size: size)

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = title
        w.contentView = hostingView
        w.center()
        w.level = .floating
        w.isReleasedWhenClosed = false
        w.minSize = minSize
        w.makeKeyAndOrderFront(nil)
        windows[id] = w
    }

    static func close(id: String) {
        windows[id]?.close()
        windows[id] = nil
    }
}
