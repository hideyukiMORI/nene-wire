import NeNeWireCore
import Testing

@testable import NeNeWireRender

/// 設定画面の描画（FR-23〜25・ADR 0011）。
struct SettingsScreenTests {
    private let clock = WallClock(year: 2026, month: 10, day: 26, hour: 21, minute: 47, second: 3, zone: "JST")

    private func editor() throws -> SettingsEditor {
        let feeds = try [
            ("NHK", "https://www.nhk.or.jp/rss/news/cat0.xml", true),
            ("BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml", false),
        ].map { name, url, on in
            try #require(FeedURL.parse(url).flatMap { Feed.make(name: name, url: $0, enabled: on) })
        }
        return SettingsEditor.opening(Settings(feeds: feeds, display: .defaults))
    }

    private func render(_ editor: SettingsEditor, frame: FrameStyle = .boxDrawing, columns: Int = 120) -> Grid {
        SettingsRenderer.render(
            editor, clock: clock, size: ScreenSize(columns: columns, rows: 30),
            style: (Theme.phosphor, TerminalTraits(frame: frame, colors: .trueColor)))
    }

    private func text(_ grid: Grid, row: Int) -> String {
        grid.row(row).reduce(into: "") { line, cell in
            switch cell.glyph {
            case .narrow(let character), .wide(let character):
                line.append(character)
            case .continuation:
                break
            }
        }
    }

    @Test func feedsAndDisplaySitSideBySide() throws {
        let grid = render(try editor())
        #expect(grid.size == ScreenSize(columns: 120, rows: 15))
        #expect(text(grid, row: 0).contains("SETUP // 設定"))
        #expect(text(grid, row: 0).contains("保存済み"))
        #expect(text(grid, row: 1).contains("[ FEEDS ]") && text(grid, row: 1).contains("2 本 · 有効 1"))
        #expect(text(grid, row: 1).contains("[ DISPLAY ]"))
        #expect(text(grid, row: 2).contains("› [x] NHK") && text(grid, row: 2).contains("www.nhk.or.jp"))
        #expect(text(grid, row: 3).contains("[ ] BBC World"))
        #expect(text(grid, row: 2).contains("表示する言語") && text(grid, row: 2).contains("‹ 日本語 ›"))
        #expect(text(grid, row: 3).contains("‹ 12 秒 ›"))
        #expect(text(grid, row: 14).contains("SPC 有効/無効"))
    }

    @Test func formsAndQuestionsAreShown() throws {
        var editing = try editor()
        _ = editing.handle(.character("a"))
        for character in "朝日" {
            _ = editing.handle(.character(character))
        }
        let form = render(editing)
        #expect(text(form, row: 9).contains("フィードを足す"))
        #expect(text(form, row: 10).contains("名前 [朝日█"))
        #expect(text(form, row: 14).contains("Enter 決める"))
        var deleting = try editor()
        _ = deleting.handle(.character("d"))
        #expect(text(render(deleting), row: 13).contains("「NHK」を消す？"))
        var closing = try editor()
        _ = closing.handle(.character(" "))
        _ = closing.handle(.escape)
        let question = render(closing)
        #expect(text(question, row: 0).contains("未保存の変更あり"))
        #expect(text(question, row: 13).contains("w 保存して閉じる"))
    }

    @Test func narrowAndAsciiTerminalsStillWork() throws {
        let grid = render(try editor(), frame: .ascii, columns: 72)
        #expect(grid.size.columns == 72)
        for row in 0..<15 {
            #expect(!text(grid, row: row).contains { "─│┌┐└┘".contains($0) })
        }
        #expect(text(render(try editor(), columns: 60), row: 0).hasPrefix("端末が小さすぎる"))
    }
}
