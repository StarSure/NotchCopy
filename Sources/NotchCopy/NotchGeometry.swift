import AppKit

/// Adapted from Cyclop. Only one panel, preferentially on the built-in notch.
struct NotchGeometry {
    let screen: NSScreen
    let notchSize: CGSize
    let centerX: CGFloat
    let isPhysical: Bool
    let hasUpperNeighbor: Bool
    static let expandedSize = CGSize(width: 500, height: 384)
    static let padding: CGFloat = 30

    @MainActor
    static func current() -> NotchGeometry? {
        let screens = NSScreen.screens.filter {
            guard let id = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return true }
            return CGDisplayMirrorsDisplay(id.uint32Value) == kCGNullDirectDisplay
        }
        guard let screen = screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens.first else { return nil }
        let physical = screen.safeAreaInsets.top > 0
        let width: CGFloat
        let depth: CGFloat
        let center: CGFloat
        if physical, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            width = screen.frame.width - left.width - right.width
            depth = screen.safeAreaInsets.top
            center = screen.frame.minX + left.width + width / 2
        } else {
            width = 180
            depth = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            center = screen.frame.midX
        }
        return NotchGeometry(screen: screen, notchSize: CGSize(width: width, height: depth),
            centerX: center, isPhysical: physical,
            hasUpperNeighbor: NotchEntryLayout.hasUpperNeighbor(screen: screen.frame, centerX: center,
                width: width, otherScreens: screens.map(\.frame)))
    }

    var frame: CGRect {
        CGRect(x: centerX - Self.expandedSize.width / 2 - Self.padding,
               y: screen.frame.maxY - Self.expandedSize.height - Self.padding,
               width: Self.expandedSize.width + 2 * Self.padding,
               height: Self.expandedSize.height + Self.padding)
    }
    var collapsedSize: CGSize { CGSize(width: notchSize.width, height: notchSize.height) }
    var openTarget: CGRect {
        NotchEntryLayout.lowerEdgeTarget(topY: screen.frame.maxY, centerX: centerX,
                                         width: notchSize.width, notchDepth: notchSize.height,
                                         hasUpperNeighbor: hasUpperNeighbor)
    }
    var closeTarget: CGRect {
        CGRect(x: centerX - Self.expandedSize.width / 2 - 12,
               y: screen.frame.maxY - Self.expandedSize.height - 10,
               width: Self.expandedSize.width + 24, height: Self.expandedSize.height + 10)
    }
    var interactiveRect: CGRect {
        CGRect(x: centerX - Self.expandedSize.width / 2 - 12,
               y: screen.frame.maxY - Self.expandedSize.height,
               width: Self.expandedSize.width + 24, height: Self.expandedSize.height)
    }
}
