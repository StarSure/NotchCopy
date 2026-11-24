import AppKit

// Compile with the app's view/controller sources, without its production entry
// point. This renders the actual UI with isolated example data and no hotkey.
MainActor.assumeIsolated {
    let arguments = ProcessInfo.processInfo.arguments
    guard arguments.contains("--demo"), arguments.count == 5,
          ["list", "search", "preview", "empty"].contains(arguments[2]) else {
        fatalError("Usage: capture --demo <scene> <examples.json> <output.png>")
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let file = Support.file("snippets.json")
    let data = try! Data(contentsOf: URL(fileURLWithPath: arguments[3]))
    let examples = try! JSONDecoder().decode([Snippet].self, from: data)
    precondition(!examples.isEmpty, "Screenshot examples must not be empty")
    try! (arguments[2] == "empty" ? Data("[]".utf8) : data).write(to: file, options: .atomic)
    let store = SnippetStore(file: file)
    store.reload()
    let controller = NotchController(store: store)
    controller.start()
    controller.show(manual: true)
    switch arguments[2] {
    case "search": store.query = "代码"
    case "preview": controller.preview(examples.last!)
    default: break
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        controller.exportDemoPreview(to: URL(fileURLWithPath: arguments[4]))
        controller.stop()
        app.terminate(nil)
    }
    app.run()
}
