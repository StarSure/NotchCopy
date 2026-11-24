import AppKit

final class NotchRootView: NSView {
    var activeRect: CGRect = .zero
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard activeRect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}
