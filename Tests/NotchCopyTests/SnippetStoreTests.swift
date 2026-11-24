import Foundation
import Testing
@testable import NotchCopy

@MainActor
struct SnippetStoreTests {

    private static func makeStore(
        contents: String? = nil,
        function: String = #function
    ) throws -> (store: SnippetStore, file: URL) {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cyclop-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("snippets.json")
        if let contents { try Data(contents.utf8).write(to: file) }
        return (SnippetStore(file: file), file)
    }

    private static func read(_ file: URL) throws -> [Snippet] {
        try JSONDecoder().decode([Snippet].self, from: Data(contentsOf: file))
    }

    // MARK: - Личность заготовки

    @Test func sameLabelDifferentTextStaysTwoSnippets() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "nox-password", text: "живой")
        store.add(label: "nox-password", text: "стенд")
        #expect(store.items.count == 2)
    }

    @Test func exactDuplicateCollapses() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "почта", text: "me@example.com")
        store.add(label: "почта", text: "me@example.com")
        #expect(store.items.count == 1)
    }

    // MARK: - Добавление

    @Test func addPutsTheNewestOnTopAndWritesTheFile() throws {
        let (store, file) = try Self.makeStore()
        store.add(label: "первая", text: "1")
        store.add(label: "вторая", text: "2")
        #expect(store.items.map(\.label) == ["вторая", "первая"])
        #expect(try Self.read(file).map(\.label) == ["вторая", "первая"])
    }

    @Test func addTrimsWhitespaceAndRefusesAnEmptyValue() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "  имя  ", text: "  значение  ")
        store.add(label: "пусто", text: "   \n  ")
        #expect(store.items.count == 1)
        #expect(store.items[0].label == "имя")
        #expect(store.items[0].text == "значение")
    }

    @Test func addRereadsWhatWasEditedByHand() throws {
        let (store, file) = try Self.makeStore()
        store.add(label: "из панели", text: "1")
        try Data(#"[{"label":"из редактора","text":"2"}]"#.utf8).write(to: file)
        store.add(label: "снова из панели", text: "3")
        #expect(store.items.map(\.label) == ["снова из панели", "из редактора"])
    }

    // MARK: - Правка (#64)

    @Test func updateEditsInPlaceAndKeepsThePosition() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "в", text: "3")
        store.add(label: "б", text: "2")
        store.add(label: "а", text: "1")
        let middle = store.items[1]
        store.update(middle, label: "б-новая", text: "2")
        #expect(store.items.map(\.label) == ["а", "б-новая", "в"])
    }

    @Test func updateIntoAnExactCopyDoesNotDestroyTheNeighbour() throws {
        let (store, file) = try Self.makeStore()
        store.add(label: "", text: "третья")
        store.add(label: "сосед", text: "не трогать")
        store.add(label: "", text: "первая")
        // Список: ["первая", "сосед", "третья"]. Правим нижнюю в копию верхней.
        let bottom = store.items[2]
        store.update(bottom, label: "", text: "первая")

        #expect(store.items.count == 2)
        #expect(store.items.map(\.text) == ["не трогать", "первая"])
        #expect(try Self.read(file).map(\.text) == ["не трогать", "первая"])
    }

    @Test func updateWithAnEmptyValueCancelsTheEdit() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "имя", text: "значение")
        store.update(store.items[0], label: "имя", text: "   ")
        #expect(store.items.map(\.text) == ["значение"])
    }

    // MARK: - Порядок

    @Test func moveReordersAndWritesTheNewOrder() throws {
        let (store, file) = try Self.makeStore()
        store.add(label: "в", text: "3")
        store.add(label: "б", text: "2")
        store.add(label: "а", text: "1")
        store.move(store.items[2], to: 0)
        #expect(store.items.map(\.label) == ["в", "а", "б"])
        #expect(try Self.read(file).map(\.label) == ["в", "а", "б"])
    }

    @Test func moveClampsAnIndexPastTheEnd() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "б", text: "2")
        store.add(label: "а", text: "1")
        store.move(store.items[0], to: 99)
        #expect(store.items.map(\.label) == ["б", "а"])
    }

    // MARK: - Разбор файла (#14)

    @Test func aSnippetWithoutALabelReadsFine() throws {
        let (store, _) = try Self.makeStore(contents: #"""
        [{"text":"без имени"},{"label":"с именем","text":"значение"}]
        """#)
        store.reload()
        #expect(store.fileBroken == false)
        #expect(store.items.count == 2)
        #expect(store.items[0].label.isEmpty)
    }

    @Test func aMissingFileIsAnEmptyListAndNotABreakage() throws {
        let (store, _) = try Self.makeStore()
        store.reload()
        #expect(store.items.isEmpty)
        #expect(store.fileBroken == false)
    }

    // MARK: - Битый файл (#7)

    private static let brokenJSON = #"[{"text":"сломанная"}"#

    @Test func aBrokenFileRaisesTheFlagAndKeepsWhatWasOnScreen() throws {
        let (store, file) = try Self.makeStore(contents: #"[{"text":"целая"}]"#)
        store.reload()
        try Data(Self.brokenJSON.utf8).write(to: file)
        store.reload()
        #expect(store.fileBroken)
        #expect(store.items.map(\.text) == ["целая"])
    }

    @Test func nothingIsWrittenOverABrokenFile() throws {
        let (store, file) = try Self.makeStore(contents: Self.brokenJSON)
        store.reload()
        store.add(label: "новая", text: "значение")
        store.update(Snippet(text: "что угодно"), label: "", text: "значение")
        store.remove(Snippet(text: "чего нет"))
        #expect(try String(contentsOf: file, encoding: .utf8) == Self.brokenJSON)
    }

    // MARK: - Запись

    @Test func theFileIsWrittenToBeReadByAHuman() throws {
        let (store, file) = try Self.makeStore()
        store.add(label: "сайт", text: "https://example.com/a/b")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("https://example.com/a/b"))
        #expect(!text.contains("\\/"))
        #expect(text.contains("\n"))
    }

    @Test func anUnnamedSnippetIsWrittenWithoutTheKey() throws {
        let (store, file) = try Self.makeStore()
        store.add(label: "", text: "значение")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("label"))
    }

    // MARK: - Поиск

    @Test func searchMatchesNameAndValueAlikeIgnoringCaseAndAccents() throws {
        let (store, _) = try Self.makeStore()
        store.add(label: "Почта", text: "me@example.com")
        store.add(label: "Nagy", text: "телефон")

        store.query = "почта"
        #expect(store.filtered.count == 1)

        store.query = "EXAMPLE"
        #expect(store.filtered.count == 1)

        store.query = "nagy"
        #expect(store.filtered.count == 1)

        store.query = "   "
        #expect(store.filtered.count == 2)
    }
}
