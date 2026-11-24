import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchController: ObservableObject {
    let store: SnippetStore
    @Published private(set) var isOpen = false
    @Published var selectedID: String?
    @Published var previewID: String?
    @Published private(set) var copiedID: String?
    private(set) var geometry: NotchGeometry?
    private var panel: NotchPanel?
    private var root: NotchRootView?
    private let pointer = PointerWatcher()
    private var observers = Set<AnyCancellable>()
    private var workspaceObservers = Set<AnyCancellable>()
    private var isPinned = false
    private var generation = 0
    private var previousApp: NSRunningApplication?
    private var keyObserver: AnyCancellable?

    init(store: SnippetStore) { self.store = store }

    func start() {
        rebuild()
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.rebuild() }.store(in: &observers)
        let center = NSWorkspace.shared.notificationCenter
        center.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.close(restoreFocus: false) }.store(in: &workspaceObservers)
        center.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in self?.close(restoreFocus: false); self?.pointer.stop() }.store(in: &workspaceObservers)
        center.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in self?.pointer.start() }.store(in: &workspaceObservers)
    }

    func stop() {
        pointer.stop()
        observers.removeAll()
        workspaceObservers.removeAll()
        panel?.contentView = nil
        panel?.orderOut(nil)
    }

    private func rebuild() {
        pointer.stop()
        generation += 1
        panel?.acceptsKeyboard = false
        panel?.orderOut(nil)
        panel?.contentView = nil
        isOpen = false
        isPinned = false
        copiedID = nil
        guard let geometry = NotchGeometry.current() else { return }
        self.geometry = geometry
        let window = NotchPanel(contentRect: geometry.frame)
        let root = NotchRootView(frame: CGRect(origin: .zero, size: geometry.frame.size))
        let hosting = NSHostingView(rootView: NotchView(controller: self, store: store, geometry: geometry))
        hosting.frame = root.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.sizingOptions = []
        root.addSubview(hosting)
        window.contentView = root
        window.ignoresMouseEvents = true
        window.onPress = { [weak self] in self?.takeKeyboard() }
        window.onEscape = { [weak self] in self?.close(restoreFocus: true) }
        window.onNavigate = { [weak self] key in self?.navigate(key) ?? false }
        window.orderFrontRegardless()
        self.panel = window
        self.root = root
        keyObserver = NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: window)
            .sink { [weak self] _ in
                guard let self, isOpen else { return }
                isPinned = false
                panel?.acceptsKeyboard = false
                close(restoreFocus: false)
            }
        pointer.setInside(false)
        let screen = geometry.screen.frame
        pointer.screenRect = CGRect(x: screen.minX, y: screen.minY, width: screen.width,
                                    height: screen.height + (geometry.hasUpperNeighbor ? 0 : 2))
        pointer.openRect = geometry.openTarget
        pointer.closeRect = geometry.closeTarget
        pointer.warmZone = CGRect(x: screen.minX, y: screen.maxY - 240, width: screen.width, height: 240)
        pointer.openDelay = { geometry.hasUpperNeighbor ? 0.12 : 0.18 }
        pointer.isPanelOpen = { [weak self] in self?.isOpen ?? false }
        pointer.onInteractiveChange = { [weak self] interactive in self?.panel?.ignoresMouseEvents = !interactive }
        pointer.onChange = { [weak self] inside in
            guard let self else { return }
            if inside { show(manual: false) }
            else if !isPinned { close(restoreFocus: false) }
        }
        pointer.start()
    }

    func toggle() {
        if isOpen { close(restoreFocus: true) } else { show(manual: true) }
    }

    func show(manual: Bool) {
        guard let geometry, let panel, let root else { return }
        if !isOpen {
            generation += 1
            let front = NSWorkspace.shared.frontmostApplication
            previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
            store.reload()
            selectedID = store.filtered.first?.id
            previewID = nil
            copiedID = nil
            root.activeRect = geometry.interactiveRect.offsetBy(dx: -geometry.frame.minX, dy: -geometry.frame.minY)
            pointer.interactiveRect = geometry.interactiveRect
            panel.orderFrontRegardless()
            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) { isOpen = true }
        }
        if manual { isPinned = true; takeKeyboard() }
        pointer.setInside(true)
    }

    func takeKeyboard() {
        guard isOpen else { return }
        panel?.acceptsKeyboard = true
    }

    func close(restoreFocus: Bool) {
        guard isOpen else { return }
        generation += 1
        let stamp = generation
        let previous = previousApp
        isPinned = false
        panel?.acceptsKeyboard = false
        pointer.requireExitBeforeReopening()
        // Let AppKit resign the field before SwiftUI folds the view.
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == stamp else { return }
            withAnimation(.easeOut(duration: 0.19)) { isOpen = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self, generation == stamp else { return }
                root?.activeRect = .zero
                pointer.interactiveRect = .zero
                panel?.ignoresMouseEvents = true
                panel?.releaseKey()
                store.query = ""
                previewID = nil
                copiedID = nil
                guard restoreFocus, let previous, !previous.isTerminated,
                      InteractionPolicy.shouldRestore(previousPID: previous.processIdentifier,
                        frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                        ownPID: ProcessInfo.processInfo.processIdentifier) else { return }
                previous.activate()
            }
        }
    }

    func copy(_ item: Snippet) {
        guard isOpen else { return }
        store.copy(item)
        copiedID = item.id
        let stamp = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self, generation == stamp else { return }
            close(restoreFocus: true)
        }
    }

    func preview(_ item: Snippet) {
        previewID = item.id
        isPinned = true
        takeKeyboard()
    }

    func edit(_ item: Snippet? = nil) {
        close(restoreFocus: false)
        SnippetEditorController.shared.present(store: store, snippet: item)
    }

    /// Export only the app's own demo view; never capture the user's desktop.
    func exportDemoPreview(to url: URL) {
        guard Support.isDemo, let root,
              let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else { return }
        root.cacheDisplay(in: root.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func navigate(_ key: UInt16) -> Bool {
        guard isOpen else { return false }
        switch key {
        case 125, 126:
            selectedID = InteractionPolicy.selection(current: selectedID, ids: store.filtered.map(\.id), delta: key == 125 ? 1 : -1)
            return true
        case 36, 76:
            let id = previewID ?? selectedID
            if let item = store.filtered.first(where: { $0.id == id }) ?? store.filtered.first { copy(item) }
            return true
        default: return false
        }
    }
}
