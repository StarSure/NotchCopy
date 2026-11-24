import Foundation

enum InteractionPolicy {
    static func selection(current: String?, ids: [String], delta: Int) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return ids.first }
        return ids[min(max(index + delta, 0), ids.count - 1)]
    }
    static func shouldRestore(previousPID: Int32, frontPID: Int32?, ownPID: Int32) -> Bool {
        previousPID != ownPID && (frontPID == ownPID || frontPID == previousPID)
    }
}
