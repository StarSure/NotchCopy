import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?
    private let hotKey = GlobalHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let store = SnippetStore()
        if Support.isDemo {
            let examples = [
                Snippet(label: "写得更简洁", text: "请精简下面的内容，保留关键信息，直接给出修改后的正文。"),
                Snippet(label: "代码审查", text: "请检查这段代码的正确性、边界情况和可维护性。先说明问题，再给出最小修改建议。"),
                Snippet(label: "会议纪要", text: "请把会议内容整理为：\n\n结论\n待办事项\n负责人和截止时间")
            ]
            try? JSONEncoder().encode(examples).write(to: store.file, options: .atomic)
        }
        store.reload()
        let controller = NotchController(store: store)
        self.controller = controller
        controller.start()
        hotKey.onPress = { [weak controller] in controller?.toggle() }
        let available = hotKey.start()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "NotchCopy")
        item.button?.image?.isTemplate = true
        let menu = NSMenu()
        menu.addItem(withTitle: "NotchCopy · 刘海文案", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: available ? "快捷键：⌃⌥V" : "⌃⌥V 已被占用，请使用菜单呼出", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for (title, action) in [("显示文案", #selector(toggle)), ("新增文案…", #selector(add)),
                                 ("打开数据与备份", #selector(reveal)), ("关于 NotchCopy", #selector(about)),
                                 ("退出", #selector(quit))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        item.menu = menu
        statusItem = item
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--show") { controller.show(manual: true) }
        if Support.isDemo, let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
            controller.show(manual: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                controller.exportDemoPreview(to: URL(fileURLWithPath: arguments[index + 1]))
                NSApp.terminate(nil)
            }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SnippetEditorController.shared.requestClose() ? .terminateNow : .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) { hotKey.stop(); controller?.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.show(manual: true)
        return true
    }
    @objc private func toggle() { controller?.toggle() }
    @objc private func add() { controller?.edit() }
    @objc private func reveal() { NSWorkspace.shared.open(Support.folder) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "NotchCopy · 刘海文案"
        alert.informativeText = "版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版")\n\n常用文案，随手复制。\n\nMIT 开源 · StarSure\n部分基础组件改编自 Cyclop，详见随附 LICENSE 与 NOTICE。\n\ngithub.com/StarSure/NotchCopy"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    private func installEditMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        for (title, action, key) in [("显示文案", #selector(toggle), "1"), ("新增文案…", #selector(add), "n"), ("退出 NotchCopy", #selector(quit), "q")] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            entry.target = self
            appMenu.addItem(entry)
        }
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
}
