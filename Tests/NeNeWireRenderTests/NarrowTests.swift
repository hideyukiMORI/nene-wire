import NeNeWireCore
import Testing

@testable import NeNeWireRender

/// 狭い端末で、状態の行とキーの行の右端が切れない（#34）。
struct NarrowTests {
    private let clock = WallClock(year: 2026, month: 10, day: 26, hour: 21, minute: 47, second: 3, zone: "JST")

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

    /// 出せるものが全部ある、いちばん長い状態の行。
    private func busiest() -> StripState {
        let feeds = [
            FeedRow(name: "NHK", health: .fetched(count: 7), fetching: false),
            FeedRow(name: "NPR", health: .failed(.status(500)), fetching: false),
        ]
        return StripState(
            article: nil, fresh: false, position: 42, count: 180, paused: true, feeds: feeds, message: "", clock: clock,
            pendingFresh: 2, translator: .ready(route: "en>ja", pending: 75, busy: true))
    }

    @Test func theStatusLineKeepsTheEssentialsAtEveryWidth() {
        for columns in [72, 80, 100, 120, 160] {
            let grid = StripRenderer.render(
                busiest(), size: ScreenSize(columns: columns, rows: 30), theme: .phosphor,
                traits: TerminalTraits(frame: .boxDrawing, colors: .trueColor))
            let line = text(grid, row: 14)
            let used = String(line.reversed().drop { $0 == " " }.reversed())
            #expect(CellWidth.of(used) <= columns, "\(columns) 桁")
            for essential in ["[042/180]", "速報 2", "停止中", "s 設定", "q 終了"] {
                #expect(line.contains(essential), "\(columns) 桁に \(essential)")
            }
        }
    }

    @Test func wideTerminalsStillShowEverything() {
        let grid = StripRenderer.render(
            busiest(), size: ScreenSize(columns: 160, rows: 30), theme: .phosphor,
            traits: TerminalTraits(frame: .boxDrawing, colors: .trueColor))
        let line = text(grid, row: 14)
        for item in ["NET", "FEED 1/2", "取得失敗 1", "TRANS en>ja", "SPC 再開", "←→ 前後", "t 翻訳"] {
            #expect(line.contains(item), "\(item)")
        }
    }

    @Test func theSettingsKeyBarKeepsSaveAndClose() throws {
        let url = try #require(FeedURL.parse("https://example.com/feed"))
        let feed = try #require(Feed.make(name: "NHK", url: url, enabled: true))
        let grid = SettingsRenderer.render(
            .opening(Settings(feeds: [feed], display: .defaults)), clock: clock,
            size: ScreenSize(columns: 72, rows: 30),
            style: (Theme.phosphor, TerminalTraits(frame: .boxDrawing, colors: .trueColor)))
        let line = text(grid, row: 14)
        #expect(line.contains("w 保存"))
        #expect(line.contains("Esc 閉じる"))
        #expect(CellWidth.of(String(line.reversed().drop { $0 == " " }.reversed())) <= 72)
    }

    @Test func lineFitDropsInTheGivenOrderOnlyUntilItFits() {
        let color = Theme.phosphor.text
        let groups = [[Segment("aaaa", color)], [Segment("bbbb", color)], [Segment("cc", color)]]
        #expect(LineFit.fit(groups, dropOrder: [1, 0], width: 10).map(\.text) == ["aaaa", "bbbb", "cc"])
        #expect(LineFit.fit(groups, dropOrder: [1, 0], width: 6).map(\.text) == ["aaaa", "cc"])
        #expect(LineFit.fit(groups, dropOrder: [1, 0], width: 3).map(\.text) == ["cc"])
    }
}
