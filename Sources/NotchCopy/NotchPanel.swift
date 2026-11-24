import AppKit

final class NotchPanel: NSPanel {
    var acceptsKeyboard = false {
        didSet {
            guard acceptsKeyboard != oldValue else { return }
            if acceptsKeyboard { makeKey() }
            // Giving it back is `releaseKey`, called separately — when it
            // happens matters, and only the controller knows when it is safe.
        }
    }

    func releaseKey() {
        guard !acceptsKeyboard, isKeyWindow else { return }
        orderOut(nil)
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    private enum Key {
        static let a: UInt16 = 0
        static let z: UInt16 = 6
        static let x: UInt16 = 7
        static let c: UInt16 = 8
        static let v: UInt16 = 9
    }

    var onPress: (() -> Void)?
    var onEscape: (() -> Void)?
    var onNavigate: ((UInt16) -> Bool)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            onEscape?()
            return
        }
        if event.type == .keyDown, onNavigate?(event.keyCode) == true { return }
        if event.type == .keyDown, editingAction(for: event) != nil, perform(event) { return }
        // Before `super`, so the window is already key by the time the click
        // reaches the field and places a caret.
        if event.type == .leftMouseDown { onPress?() }
        super.sendEvent(event)
    }

    private func editingAction(for event: NSEvent) -> Selector? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.subtracting(.shift) == .command else { return nil }
        switch event.keyCode {
        case Key.a: return #selector(NSText.selectAll(_:))
        case Key.x: return #selector(NSText.cut(_:))
        case Key.c: return #selector(NSText.copy(_:))
        case Key.v: return #selector(NSText.paste(_:))
        // Undo and redo are informal: nothing declares them, the Edit menu just
        // names the selector and lets the chain find an undo manager.
        case Key.z: return flags.contains(.shift) ? Selector(("redo:")) : Selector(("undo:"))
        default: return nil
        }
    }

    private func perform(_ event: NSEvent) -> Bool {
        guard let action = editingAction(for: event), let responder = firstResponder else { return false }
        return responder.tryToPerform(action, with: self)
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // The panel is dark whatever the system is: it lies over the notch,
        // which is black on every Mac that has one. Everything drawn by hand
        // already knows that, but the AppKit views behind SwiftUI's controls do
        // not — a `TextField` asks the effective appearance what colour text
        // is, and on a Mac set to light it is told black. The result is a field
        // one can type into and not read: the caret blinks, the text lands, and
        // none of it is visible against the panel.
        appearance = NSAppearance(named: .darkAqua)

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        // One notch above the status bar so we cover the menu bar itself.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }
}
