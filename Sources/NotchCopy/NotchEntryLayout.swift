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
        let targetWidth = max(1, width - 24)
        return CGRect(x: centerX - targetWidth / 2,
                      y: topY - notchDepth - 10,
                      width: targetWidth, height: 24)
    }
}
