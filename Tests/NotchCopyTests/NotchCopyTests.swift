import Foundation
import Testing
@testable import NotchCopy

@MainActor
struct NotchCopyTests {
    @Test func chineseMultilineTextSurvivesEditingAndRelaunch() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("snippets.json")
        let store = SnippetStore(file: file)
        store.add(label: "多行文案", text: "第一行：中文与 English\n\n第二段 😊\nhttps://example.com?a=1&b=2")
        let original = try #require(store.items.first)
        store.update(original, label: "已编辑", text: original.text + "\n第三行")
        let relaunched = SnippetStore(file: file)
        relaunched.reload()
        #expect(relaunched.items.first?.label == "已编辑")
        #expect(relaunched.items.first?.text == original.text + "\n第三行")
        relaunched.query = "第二段"
        #expect(relaunched.filtered.count == 1)
        #expect(store.saveError == nil)
    }
    @Test func failedWriteReportsErrorAndDoesNotPretendSaved() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("missing/snippets.json")
        let store = SnippetStore(file: file)
        store.add(label: "不能保存", text: "正文")
        #expect(store.saveError != nil)
        #expect(store.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
    @Test func deletedWhileEditingDoesNotReportSuccess() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SnippetStore(file: folder.appendingPathComponent("snippets.json"))
        store.add(label: "原文", text: "正文")
        let item = try #require(store.items.first)
        store.remove(item)
        store.update(item, label: "编辑", text: "新正文")
        #expect(store.saveError != nil)
        #expect(store.items.isEmpty)
    }
}
