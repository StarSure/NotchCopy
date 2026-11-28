import Foundation
import Testing
@testable import NotchCopy

@MainActor
struct PointerWatcherTests {
    private func watcher(hasUpperNeighbor: Bool = true) -> PointerWatcher {
        let watcher = PointerWatcher()
        watcher.screenRect = CGRect(x: 0, y: 0, width: 1512, height: hasUpperNeighbor ? 982 : 984)
        watcher.openRect = NotchEntryLayout.lowerEdgeTarget(topY: 982, centerX: 756, width: 185,
                                                          notchDepth: 32, hasUpperNeighbor: hasUpperNeighbor)
        watcher.closeRect = CGRect(x: 464, y: 580, width: 584, height: 402)
        return watcher
    }

    @Test func restingNearLowerEdgeOpensWithoutTakingClicks() {
        let watcher = watcher()
        var changes: [Bool] = []
        var interactive: [Bool] = []
        watcher.onChange = { changes.append($0) }
        watcher.onInteractiveChange = { interactive.append($0) }
        let time = Date(timeIntervalSinceReferenceDate: 0)
        let point = CGPoint(x: 756, y: 946)
        watcher.process(point: point, at: time)
        watcher.process(point: point, at: time.addingTimeInterval(0.06))
        #expect(changes.isEmpty)
        watcher.process(point: point, at: time.addingTimeInterval(0.09))
        #expect(changes == [true])
        #expect(interactive == [false])
    }

    @Test func fastPassIntoUpperDisplayDoesNotOpen() {
        let watcher = watcher()
        var changes: [Bool] = []
        watcher.onChange = { changes.append($0) }
        let time = Date(timeIntervalSinceReferenceDate: 0)
        watcher.process(point: CGPoint(x: 756, y: 946), at: time)
        watcher.process(point: CGPoint(x: 756, y: 983), at: time.addingTimeInterval(0.04))
        watcher.process(point: CGPoint(x: 756, y: 990), at: time.addingTimeInterval(0.5))
        #expect(changes.isEmpty)
        #expect(!watcher.isInside)
    }

    @Test func aFastApproachThatStopsAtTheSingleDisplayTopStillOpens() {
        let watcher = watcher(hasUpperNeighbor: false)
        var changes: [Bool] = []
        watcher.onChange = { changes.append($0) }
        let time = Date(timeIntervalSinceReferenceDate: 0)
        watcher.process(point: CGPoint(x: 756, y: 946), at: time)
        watcher.process(point: CGPoint(x: 756, y: 981), at: time.addingTimeInterval(0.04))
        #expect(changes.isEmpty)
        watcher.process(point: CGPoint(x: 756, y: 981), at: time.addingTimeInterval(0.10))
        #expect(changes == [true])
    }

    @Test func theUpperDisplayBoundaryStillDoesNotOpenWhenRestingThere() {
        let watcher = watcher()
        var changes: [Bool] = []
        watcher.onChange = { changes.append($0) }
        let time = Date(timeIntervalSinceReferenceDate: 0)
        watcher.process(point: CGPoint(x: 756, y: 946), at: time)
        watcher.process(point: CGPoint(x: 756, y: 981), at: time.addingTimeInterval(0.04))
        watcher.process(point: CGPoint(x: 756, y: 981), at: time.addingTimeInterval(1))
        #expect(changes.isEmpty)
    }

    @Test func leavingTheTargetResetsDwellBeforeReturning() {
        let watcher = watcher()
        var changes: [Bool] = []
        watcher.onChange = { changes.append($0) }
        let time = Date(timeIntervalSinceReferenceDate: 0)
        let inside = CGPoint(x: 756, y: 930)
        watcher.process(point: inside, at: time)
        watcher.process(point: CGPoint(x: 756, y: 920), at: time.addingTimeInterval(0.05))
        watcher.process(point: inside, at: time.addingTimeInterval(0.10))
        watcher.process(point: inside, at: time.addingTimeInterval(0.16))
        #expect(changes.isEmpty)
        watcher.process(point: inside, at: time.addingTimeInterval(0.19))
        #expect(changes == [true])
    }

    @Test func leavingToUpperScreenClosesAndDoesNotImmediatelyReopen() {
        let watcher = watcher()
        var changes: [Bool] = []
        watcher.onChange = { changes.append($0) }
        watcher.setInside(true)
        let time = Date(timeIntervalSinceReferenceDate: 0)
        let point = CGPoint(x: 756, y: 983)
        watcher.process(point: point, at: time)
        watcher.process(point: point, at: time.addingTimeInterval(0.31))
        watcher.process(point: point, at: time.addingTimeInterval(0.7))
        #expect(changes == [false])
        #expect(!watcher.isInside)
    }
}

@MainActor
struct PointerReopenTests {
    @Test func copyingDoesNotReopenUntilCursorLeavesTarget() {
        let watcher = PointerWatcher()
        watcher.openRect = CGRect(x: 0, y: 0, width: 100, height: 24)
        watcher.openDelay = { 0.1 }
        var changes: [Bool] = []
        watcher.onChange = { changes.append($0) }
        let start = Date(timeIntervalSinceReferenceDate: 0)
        watcher.requireExitBeforeReopening()
        watcher.process(point: CGPoint(x: 50, y: 10), at: start)
        watcher.process(point: CGPoint(x: 50, y: 10), at: start.addingTimeInterval(1))
        #expect(changes.isEmpty)
        watcher.process(point: CGPoint(x: 50, y: -10), at: start.addingTimeInterval(2))
        watcher.process(point: CGPoint(x: 50, y: 10), at: start.addingTimeInterval(3))
        watcher.process(point: CGPoint(x: 50, y: 10), at: start.addingTimeInterval(3.2))
        #expect(changes == [true])
    }
}

@MainActor
struct PointerRebuildTests {
    @Test func stoppingDropsThePreviousWindowsClickArea() {
        let watcher = PointerWatcher()
        watcher.interactiveRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        watcher.stop()
        var states: [Bool] = []
        watcher.onInteractiveChange = { states.append($0) }
        watcher.process(point: CGPoint(x: 50, y: 50), at: Date())
        #expect(states == [false])
    }
}
