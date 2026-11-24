import AppKit
import SwiftUI

@MainActor
final class SnippetEditorController: NSObject, NSWindowDelegate {
    static let shared = SnippetEditorController()
    private var window: NSWindow?
    private var hasChanges: () -> Bool = { false }

    func present(store: SnippetStore, snippet: Snippet? = nil) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 470),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = snippet == nil ? "新增文案" : "编辑文案"
        window.minSize = NSSize(width: 460, height: 380)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.delegate = self
        window.contentView = NSHostingView(rootView: SnippetEditorView(store: store, snippet: snippet,
            onChange: { [weak self] check in self?.hasChanges = check },
            onSave: { [weak self] in self?.hasChanges = { false }; self?.window?.close() },
            onCancel: { [weak self] in self?.window?.performClose(nil) }))
        self.window = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func requestClose() -> Bool {
        guard let window else { return true }
        guard windowShouldClose(window) else { return false }
        window.close()
        return true
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hasChanges() else { return true }
        let alert = NSAlert()
        alert.messageText = "放弃未保存的修改？"
        alert.informativeText = "点击「继续编辑」可返回保存。"
        alert.addButton(withTitle: "继续编辑")
        alert.addButton(withTitle: "放弃修改")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func windowWillClose(_ notification: Notification) {
        window = nil
        hasChanges = { false }
    }
}

private struct SnippetEditorView: View {
    @ObservedObject var store: SnippetStore
    let snippet: Snippet?
    let onChange: (@escaping () -> Bool) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var title = ""
    @State private var text = ""
    @State private var error: String?
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(snippet == nil ? "保存一段常用文案" : "编辑你的文案")
                .font(.system(size: 20, weight: .semibold))
            Text("保存后，鼠标移到刘海即可找到并复制。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("标题").font(.system(size: 12, weight: .medium))
                TextField("例如：常用回复、提示词、发布文案", text: $title)
                    .textFieldStyle(.roundedBorder).focused($titleFocused)
                    .accessibilityIdentifier("editor-title")
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("文案正文").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(text.count) 字").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                TextEditor(text: $text)
                    .font(.system(size: 14)).lineSpacing(5)
                    .padding(8).scrollContentBackground(.hidden)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.1)))
                    .accessibilityLabel("文案正文").accessibilityIdentifier("editor-body")
            }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(.orange) }
            HStack {
                Text("支持多行文字，保留换行").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("取消", action: onCancel).keyboardShortcut(.cancelAction)
                Button("保存文案", action: save)
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-snippet")
            }
        }
        .padding(24)
        .onAppear {
            title = snippet?.label ?? ""
            text = snippet?.text ?? ""
            titleFocused = true
            updateDirtyCheck()
        }
        .onChange(of: title) { _, _ in updateDirtyCheck() }
        .onChange(of: text) { _, _ in updateDirtyCheck() }
    }
    private func updateDirtyCheck() {
        let changed = title != (snippet?.label ?? "") || text != (snippet?.text ?? "")
        onChange { changed }
    }
    private func save() {
        if let snippet {
            store.update(snippet, label: title, text: text)
        } else {
            store.add(label: title, text: text)
        }
        if store.fileBroken || store.saveError != nil {
            error = store.saveError ?? "文案文件读取失败，未覆盖原文件。"
            return
        }
        onSave()
    }
}
