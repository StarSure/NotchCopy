import AppKit

extension Notification.Name {
    static let snippetStoreChanged = Notification.Name("NotchCopySnippetStoreChanged")
}


struct Snippet: Identifiable, Codable, Equatable {
    var id: String { "\(label)\u{0}\(text)" }
    var label: String = ""
    var text: String

    var symbol: String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("@"), !value.contains(" ") { return "at" }
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return "link" }
        let digits = value.filter(\.isNumber).count
        if digits >= 7, value.allSatisfy({ $0.isNumber || " +-()".contains($0) }) { return "phone.fill" }
        return "text.alignleft"
    }

    private enum CodingKeys: String, CodingKey { case label, text }

    init(label: String = "", text: String) {
        self.label = label
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        text = try container.decode(String.self, forKey: .text)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !label.isEmpty { try container.encode(label, forKey: .label) }
        try container.encode(text, forKey: .text)
    }
}

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var items: [Snippet] = []
    @Published var query = ""
    @Published private(set) var fileBroken = false
    @Published private(set) var saveError: String?

    var filtered: [Snippet] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { $0.label.matches(needle) || $0.text.matches(needle) }
    }

    let file: URL

    init(file: URL = Support.file("snippets.json")) {
        self.file = file
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: file.path) else {
            // No file is an honest empty list, and writing one is safe.
            items = []
            fileBroken = false
            return
        }
        do {
            let data = try Data(contentsOf: file)
            items = try JSONDecoder().decode([Snippet].self, from: data)
            fileBroken = false
        } catch {
            // The file exists and says something — it just cannot be read.
            // Keep whatever was on screen, raise the flag, and let the pane
            // say so: silence here is what used to turn a stray comma into a
            // lost file.
            fileBroken = true
            NSLog("NotchCopy: snippets.json is not readable: \(error.localizedDescription)")
        }
    }

    func add(label: String, text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let snippet = Snippet(label: label.trimmingCharacters(in: .whitespacesAndNewlines), text: value)
        reload()
        // A file that could not be read must not be written. The snippet is
        // dropped rather than kept in memory as if saved: pretending would
        // trade a visible refusal now for a silent loss at relaunch.
        guard !fileBroken else {
            NSLog("NotchCopy: refusing to write over an unreadable snippets.json")
            return
        }
        // Only an exact duplicate — same name and same value — is dropped, and
        // it is dropped because two identical rows are indistinguishable in the
        // list anyway. Two snippets sharing a name but not a value are kept
        // apart: see `Snippet.id`.
        items.removeAll { $0.id == snippet.id }
        items.insert(snippet, at: 0)
        persist()
    }

    func remove(_ snippet: Snippet) {
        reload()
        guard !fileBroken else { return }
        items.removeAll { $0.id == snippet.id }
        persist()
    }

    func move(_ snippet: Snippet, to index: Int) {
        reload()
        guard !fileBroken else { return }
        guard let current = items.firstIndex(where: { $0.id == snippet.id }) else { return }
        let target = max(0, min(index, items.count - 1))
        guard target != current else { return }
        items.insert(items.remove(at: current), at: target)
        persist()
    }

    func update(_ snippet: Snippet, label: String, text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let edited = Snippet(label: label.trimmingCharacters(in: .whitespacesAndNewlines), text: value)
        guard edited != snippet else { return }

        reload()
        // A file that could not be read must not be written over.
        guard !fileBroken else {
            NSLog("NotchCopy: refusing to write over an unreadable snippets.json")
            return
        }
        // An edit that turns this row into an exact copy of another one leaves
        // a single row, for the same reason `add` does.
        items.removeAll { $0.id == edited.id && $0.id != snippet.id }
        // Found after the removal, never before it: a copy standing above this
        // row shifts it up by one, and an index taken beforehand then points at
        // the neighbour. Written there, the edit destroys a snippet nobody
        // touched and leaves the edited one exactly as it was.
        guard let index = items.firstIndex(where: { $0.id == snippet.id }) else {
            saveError = "这条文案已被移除，请重新新增。"
            return
        }
        items[index] = edited
        persist()
    }

    private func persist() {
        guard !fileBroken else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let backupFolder = file.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
                try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
                let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
                let backup = backupFolder.appendingPathComponent("snippets-\(day).json")
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try Data(contentsOf: file).write(to: backup, options: .atomic)
                }
            }
            try encoder.encode(items).write(to: file, options: .atomic)
            saveError = nil
            NotificationCenter.default.post(name: .snippetStoreChanged, object: nil)
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
            reload()
            NSLog("NotchCopy: cannot write snippets.json: \(error.localizedDescription)")
        }
    }

    func copy(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
    }

    func reveal() {
        if !FileManager.default.fileExists(atPath: file.path) {
            try? Data("[]".utf8).write(to: file)
        }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }
}

private extension String {
    func matches(_ needle: String) -> Bool {
        range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
