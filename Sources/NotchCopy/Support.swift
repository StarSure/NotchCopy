import Foundation

enum Support {
    static let isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
    static let folder: URL = {
        let url: URL
        if isDemo {
            url = FileManager.default.temporaryDirectory.appendingPathComponent("NotchCopy-Demo", isDirectory: true)
        } else {
            url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NotchCopy", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    static func file(_ name: String) -> URL { folder.appendingPathComponent(name) }
}

func localized(_ key: String) -> String { key }
