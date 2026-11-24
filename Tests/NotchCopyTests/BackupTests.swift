import Foundation
import Testing
@testable import NotchCopy

@MainActor
struct BackupTests {
    @Test func firstEditOfTheDayPreservesExistingFileAndLaterEditsKeepThatSnapshot() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("snippets.json")
        let original = [Snippet(label: "原内容", text: "保留原内容")]
        let originalData = try JSONEncoder().encode(original)
        try originalData.write(to: file)
        let store = SnippetStore(file: file)
        store.add(label: "新内容", text: "第一次编辑")
        let files = try FileManager.default.contentsOfDirectory(at: folder.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        let backup = try #require(files.first)
        #expect(try Data(contentsOf: backup) == originalData)
        store.add(label: "再增加", text: "第二次编辑")
        #expect(try Data(contentsOf: backup) == originalData)
        #expect(store.items.count == 3)
    }
}
