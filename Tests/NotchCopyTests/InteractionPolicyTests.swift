import Testing
@testable import NotchCopy

struct InteractionPolicyTests {
    @Test func searchAndArrowSelectionStayWithinResults() {
        #expect(InteractionPolicy.selection(current: nil, ids: [], delta: 1) == nil)
        #expect(InteractionPolicy.selection(current: "removed", ids: ["a", "b"], delta: 1) == "a")
        #expect(InteractionPolicy.selection(current: "a", ids: ["a", "b"], delta: 1) == "b")
        #expect(InteractionPolicy.selection(current: "b", ids: ["a", "b"], delta: 1) == "b")
        #expect(InteractionPolicy.selection(current: "a", ids: ["a", "b"], delta: -1) == "a")
    }
    @Test func copyDoesNotStealFocusAfterUserSwitchesApps() {
        #expect(InteractionPolicy.shouldRestore(previousPID: 1, frontPID: 2, ownPID: 2))
        #expect(InteractionPolicy.shouldRestore(previousPID: 1, frontPID: 1, ownPID: 2))
        #expect(!InteractionPolicy.shouldRestore(previousPID: 1, frontPID: 3, ownPID: 2))
        #expect(!InteractionPolicy.shouldRestore(previousPID: 2, frontPID: 2, ownPID: 2))
    }
}
