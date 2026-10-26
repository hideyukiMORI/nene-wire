import Testing

@testable import NeNeWireCore

/// 設定の保存形式と、設定画面の編集の規則（FR-23〜25・ADR 0011）。
struct SettingsTests {
    private func feed(_ name: String, _ url: String, on: Bool = true) -> Feed? {
        FeedURL.parse(url).flatMap { Feed.make(name: name, url: $0, enabled: on) }
    }

    private func sample() throws -> Settings {
        Settings(
            feeds: try [
                #require(feed("NHK", "https://www.nhk.or.jp/rss/news/cat0.xml")),
                #require(feed("朝日 Headlines", "https://www.asahi.com/rss/asahi/newsheadlines.rdf", on: false)),
            ], display: .defaults)
    }

    @Test func settingsSurviveARoundTrip() throws {
        let settings = Settings(
            feeds: try sample().feeds,
            display: try #require(
                DisplaySettings.make(
                    language: "en", interval: 20, theme: "CYAN", switches: (rain: false, original: true))))
        #expect(SettingsCodec.decode(SettingsCodec.encode(settings)) == .parsed(settings))
    }

    @Test func unreadableSettingsAreNamedNotSilentlyDefaulted() {
        #expect(SettingsCodec.decode("hello") == .rejected(.notSettings))
        #expect(SettingsCodec.decode("nene-wire-settings 9\n") == .rejected(.unknownVersion("9")))
        #expect(SettingsCodec.decode("nene-wire-settings 1\ncolour red\n") == .rejected(.malformed(line: 2)))
        #expect(SettingsCodec.decode("nene-wire-settings 1\nfeed on\tX\tftp://x\n") == .rejected(.malformed(line: 2)))
        #expect(SettingsCodec.decode("nene-wire-settings 1\ninterval 7\n") == .rejected(.malformed(line: 1)))
    }

    @Test func missingKeysTakeTheDefaultsAndCommentsAreSkipped() {
        let decoded = SettingsCodec.decode("nene-wire-settings 1\r\n# memo\r\n\r\ntheme MAGENTA\r\n")
        guard case .parsed(let settings) = decoded else {
            Issue.record("読めない")
            return
        }
        #expect(settings.display.theme == "MAGENTA")
        #expect(settings.display.interval == 12)
        #expect(settings.feeds.isEmpty)
    }

    @Test func displayOptionsCycleWithinTheirChoices() {
        let base = DisplaySettings.defaults
        #expect(base.stepping(.language, by: -1).language == "es")
        #expect(base.stepping(.interval, by: 1).interval == 15)
        #expect(base.stepping(.theme, by: 4).theme == "PHOSPHOR")
        #expect(!base.stepping(.rain, by: 1).rain)
    }

    @Test func browsingTogglesSwitchesPanesAndSaves() throws {
        var editor = SettingsEditor.opening(try sample())
        #expect(editor.handle(.down) == .none)
        #expect(editor.selectedFeed == 1)
        _ = editor.handle(.character(" "))
        #expect(editor.settings.feeds[1].enabled)
        #expect(editor.isDirty)
        _ = editor.handle(.tab)
        _ = editor.handle(.down)
        _ = editor.handle(.right)
        #expect(editor.settings.display.interval == 15)
        #expect(editor.handle(.character("w")) == .save(editor.settings))
        editor.didSave()
        #expect(!editor.isDirty)
        #expect(editor.handle(.escape) == .close)
    }

    @Test func addingAFeedValidatesTheURLAndTheName() throws {
        var editor = SettingsEditor.opening(try sample())
        _ = editor.handle(.character("a"))
        for character in "BBC" {
            _ = editor.handle(.character(character))
        }
        _ = editor.handle(.tab)
        for character in "feeds.bbci.co.uk" {
            _ = editor.handle(.character(character))
        }
        _ = editor.handle(.enter)
        #expect(editor.notice?.contains("http") == true)
        #expect(editor.mode == .form(FeedForm(name: "BBC", url: "feeds.bbci.co.uk", field: .url, editing: nil)))

        var unnamed = SettingsEditor.opening(try sample())
        _ = unnamed.handle(.character("a"))
        _ = unnamed.handle(.tab)
        for character in "https://feeds.bbci.co.uk/news/world/rss.xml" {
            _ = unnamed.handle(.character(character))
        }
        _ = unnamed.handle(.enter)
        #expect(unnamed.notice == "名前が空")
        #expect(unnamed.settings.feeds.count == 2)
    }

    @Test func editingReplacesAndAddingAppends() throws {
        var editor = SettingsEditor.opening(try sample())
        _ = editor.handle(.character("e"))
        for _ in 0..<3 {
            _ = editor.handle(.backspace)
        }
        for character in "NHK 総合" {
            _ = editor.handle(.character(character))
        }
        _ = editor.handle(.enter)
        #expect(editor.settings.feeds[0].name == "NHK 総合")
        #expect(editor.mode == .browse)
        _ = editor.handle(.character("a"))
        for character in "Guardian" {
            _ = editor.handle(.character(character))
        }
        _ = editor.handle(.down)
        for character in "https://www.theguardian.com/world/rss" {
            _ = editor.handle(.character(character))
        }
        _ = editor.handle(.enter)
        #expect(editor.settings.feeds.count == 3)
        #expect(editor.selectedFeed == 2)
        _ = editor.handle(.character("a"))
        _ = editor.handle(.escape)
        #expect(editor.settings.feeds.count == 3)
    }

    @Test func deletingAsksFirst() throws {
        var editor = SettingsEditor.opening(try sample())
        _ = editor.handle(.character("d"))
        #expect(editor.mode == .confirmDelete)
        _ = editor.handle(.character("n"))
        #expect(editor.settings.feeds.count == 2)
        _ = editor.handle(.down)
        _ = editor.handle(.character("d"))
        _ = editor.handle(.character("y"))
        #expect(editor.settings.feeds.map(\.name) == ["NHK"])
        #expect(editor.selectedFeed == 0)
    }

    @Test func closingWithUnsavedChangesAsksFirst() throws {
        var editor = SettingsEditor.opening(try sample())
        _ = editor.handle(.character(" "))
        #expect(editor.handle(.escape) == .none)
        #expect(editor.mode == .confirmClose)
        #expect(editor.handle(.character("q")) == .none)
        #expect(editor.handle(.escape) == .none)
        #expect(editor.mode == .browse)
        _ = editor.handle(.escape)
        #expect(editor.handle(.character("w")) == .saveAndClose(editor.settings))
        _ = editor.handle(.escape)
        _ = editor.handle(.escape)
        #expect(editor.mode == .confirmClose)
        #expect(editor.handle(.character("x")) == .close)
    }

    @Test func testingAFeedAsksTheRootToFetchIt() throws {
        var editor = SettingsEditor.opening(try sample())
        let first = try sample().feeds[0]
        #expect(editor.handle(.character("t")) == .test(first))
        #expect(editor.testResult?.contains("NHK") == true)
        editor.reportTest("NHK  7 件 · ja · 0.11 秒  OK")
        #expect(editor.testResult == "NHK  7 件 · ja · 0.11 秒  OK")
    }
}
