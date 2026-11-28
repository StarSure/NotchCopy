import Foundation

enum NotchEntryLayout {
    static func hasUpperNeighbor(screen: CGRect, centerX: CGFloat, width: CGFloat,
                                otherScreens: [CGRect]) -> Bool {
        let left = centerX - width / 2
        let right = centerX + width / 2
        return otherScreens.contains { other in
            other != screen && abs(other.minY - screen.maxY) <= 1
                && other.maxY > screen.maxY
                && other.minX < right && other.maxX > left
        }
    }
    static func lowerEdgeTarget(topY: CGFloat, centerX: CGFloat, width: CGFloat,
                                notchDepth: CGFloat, hasUpperNeighbor: Bool) -> CGRect {
        // At a physical screen edge, the pointer naturally comes to rest at
        // the very top. Only reserve a gap where it can cross to an upper
        // display; otherwise that gap becomes a permanent hover dead zone.
        let targetWidth = max(1, width - 8)
        let bottom = topY - notchDepth - 22
        let top = hasUpperNeighbor ? topY - 8 : topY + 2
        return CGRect(x: centerX - targetWidth / 2,
                      y: bottom,
                      width: targetWidth, height: max(1, top - bottom))
    }
}
