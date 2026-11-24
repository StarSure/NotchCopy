import Foundation
import Testing
@testable import NotchCopy

struct NotchEntryLayoutTests {
    let builtIn = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func actualStackedDisplayUsesLowerEntry() {
        let upper = CGRect(x: -294, y: 982, width: 1920, height: 1080)
        #expect(NotchEntryLayout.hasUpperNeighbor(screen: builtIn, centerX: 756, width: 185,
                                               otherScreens: [builtIn, upper]))
    }
    @Test func singleDisplayAndSideBySideKeepOriginalEntry() {
        #expect(!NotchEntryLayout.hasUpperNeighbor(screen: builtIn, centerX: 756, width: 185,
                                                otherScreens: [builtIn]))
        let beside = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        #expect(!NotchEntryLayout.hasUpperNeighbor(screen: builtIn, centerX: 756, width: 185,
                                                otherScreens: [builtIn, beside]))
    }
    @Test func upperDisplayAwayFromNotchDoesNotChangeEntry() {
        let upperRight = CGRect(x: 900, y: 982, width: 1920, height: 1080)
        #expect(!NotchEntryLayout.hasUpperNeighbor(screen: builtIn, centerX: 756, width: 185,
                                                otherScreens: [builtIn, upperRight]))
    }
    @Test func hiddenTargetOpensBelowBoundaryWithoutCoveringAWindow() {
        let target = NotchEntryLayout.lowerEdgeTarget(topY: 982, centerX: 756,
                                                     width: 185, notchDepth: 32)
        #expect(builtIn.contains(target))
        #expect(target.maxY == 964)
        #expect(target.contains(CGPoint(x: 756, y: 946)))
        #expect(target.contains(CGPoint(x: 756, y: 956)))
        #expect(!target.contains(CGPoint(x: 756, y: 982)))
        #expect(!target.contains(CGPoint(x: 756, y: 983)))
    }
    @Test func passingOverNeighbouringMenuItemsDoesNotTrigger() {
        let target = NotchEntryLayout.lowerEdgeTarget(topY: 982, centerX: 756,
                                                     width: 185, notchDepth: 32)
        #expect(!target.contains(CGPoint(x: 660, y: 950)))
        #expect(!target.contains(CGPoint(x: 852, y: 950)))
        #expect(!target.contains(CGPoint(x: 756, y: 920)))
    }
}
