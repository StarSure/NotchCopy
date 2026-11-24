import AppKit

@MainActor
final class PointerWatcher {
    var openRect: CGRect = .zero
    var screenRect: CGRect = .infinite
    var closeRect: CGRect = .zero
    var interactiveRect: CGRect = .zero
    var isDragging: () -> Bool = { false }
    var isPanelOpen: () -> Bool = { false }

    var openDelay: () -> TimeInterval = { 0.2 }
    var closeDelay: TimeInterval = 0.3

    var warmZone: CGRect = .zero
    var coolMargin: CGFloat = 80
    var restThreshold: TimeInterval = 3

    private let fastInterval: TimeInterval = 1.0 / 60
    private let idleInterval: TimeInterval = 1.0 / 8

    var onChange: ((Bool) -> Void)?
    var onInteractiveChange: ((Bool) -> Void)?

    private(set) var isInside = false
    private var timer: Timer?
    private var awaitingSince: Date?
    private var waitingForExit = false
    private var wasInteractive: Bool?
    private var isWarm = false
    private var lastPoint = CGPoint(x: -1, y: -1)
    private var lastMovedAt = Date.distantPast

    func start() {
        schedule(warm: false)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        awaitingSince = nil
        // The last sent interactivity dies with the panel it was sent to. The
        // watcher outlives a rebuild, and a fresh panel starts click-through;
        // holding on to the old "already interactive" would swallow the first
        // callback and leave the new panel deaf to clicks until the pointer
        // wandered out and back (#6).
        wasInteractive = nil
    }

    private func schedule(warm: Bool) {
        timer?.invalidate()
        isWarm = warm
        let interval = warm ? fastInterval : idleInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // The idle timer may drift by half its beat: nothing it watches for
        // resolves faster than that, and the slack lets the system fold the
        // wake-up into others it was making anyway. The fast timer keeps its
        // precision — it is the one measuring dwell.
        timer.tolerance = warm ? interval / 4 : interval / 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func updateRate(for point: CGPoint) {
        if point != lastPoint {
            lastPoint = point
            lastMovedAt = Date()
        }
        let moving = Date().timeIntervalSince(lastMovedAt) < restThreshold
        let near: Bool
        if isInside {
            near = true
        } else if isWarm {
            near = point.y >= warmZone.minY - coolMargin
        } else {
            near = warmZone.contains(point)
        }
        let warm = near && moving
        guard warm != isWarm else { return }
        schedule(warm: warm)
    }

    func setInside(_ value: Bool) {
        awaitingSince = nil
        isInside = value
    }

    func requireExitBeforeReopening() {
        waitingForExit = true
        setInside(false)
    }

    private func tick() {
        let point = NSEvent.mouseLocation
        updateRate(for: point)
        process(point: point, at: Date())
    }

    func process(point: CGPoint, at now: Date) {
        let onScreen = screenRect.contains(point)
        let interactive = isDragging() || (onScreen && interactiveRect.contains(point))
        if wasInteractive != interactive {
            wasInteractive = interactive
            onInteractiveChange?(interactive)
        }

        if waitingForExit {
            if !onScreen || !openRect.contains(point) { waitingForExit = false }
            else { return }
        }
        let inside = onScreen && (isInside ? closeRect : openRect).contains(point)

        // Whether the panel is open and where the pointer is are two separate
        // facts, and only one of them is tracked here. They are supposed to
        // agree, but every path that opens the panel without the pointer —
        // a drop, the menu bar, a tab claiming the keyboard — is a chance for
        // them to come apart, and the shape that costs the user something is
        // always the same: a panel standing open with the mouse nowhere near
        // it, waiting for a hover that already happened. Whatever led there,
        // the pointer is the authority, so say so again.
        // A drag is the one time the panel is meant to stand open with the
        // pointer off it: it was opened to be dropped onto.
        if !inside, !isInside, !isDragging(), isPanelOpen() {
            guard let start = awaitingSince else {
                awaitingSince = now
                return
            }
            guard now.timeIntervalSince(start) >= closeDelay else { return }
            awaitingSince = nil
            onChange?(false)
            return
        }

        guard inside != isInside else {
            awaitingSince = nil
            return
        }
        guard let start = awaitingSince else {
            awaitingSince = now
            return
        }
        guard now.timeIntervalSince(start) >= (inside ? openDelay() : closeDelay) else { return }
        awaitingSince = nil
        isInside = inside
        onChange?(inside)
    }
}

