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
                                notchDepth: CGFloat) -> CGRect {
        // Cover more of the notch and the approach from below, while keeping
        // clear of adjacent menu items and the upper display boundary.
        let targetWidth = max(1, width - 8)
        let bottom = topY - notchDepth - 22
        let top = topY - 8
        return CGRect(x: centerX - targetWidth / 2,
                      y: bottom,
                      width: targetWidth, height: max(1, top - bottom))
    }
}
