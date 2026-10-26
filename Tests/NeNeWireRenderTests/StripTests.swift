import NeNeWireCore
import Testing

@testable import NeNeWireRender

/// 帯の形（FR-14・FR-15・FR-21・ADR 0006）。
struct StripTests {
    private let clock = WallClock(year: 2026, month: 10, day: 26, hour: 21, minute: 47, second: 3, zone: "JST")
    private let traits = TerminalTraits(frame: .boxDrawing, colors: .trueColor)

    private func sample() -> Article? {
        let xml = """
            <rss version="2.0"><channel><title>t</title><item><title>北海の洋上風力、送電網の遅れで全面稼働が半年ずれ込む</title>
            <link>https://example.com/news/0001</link><guid>g1</guid><pubDate>Mon, 26 Oct 2026 12:31:00 GMT</pubDate>
            <description>英国北部の洋上風力発電所で、陸上の送電網の整備が追いつかず、全面稼働が来年春までずれ込む見通しとなった。運営会社は、完成済みの風車の一部を止めたまま保守を続けている。</description>
            </item></channel></rss>
            """
        guard case .parsed(let document) = FeedParser.parse(xml), let item = document.items.first,
            let url = FeedURL.parse("https://example.com/feed"),
            let feed = Feed.make(name: "BBC World", url: url, enabled: true)
        else {
            return nil
        }
        return Article.from(item, feed: feed)
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

    /// 桁の範囲の文字（全角の右半分は飛ばす）。
    private func text(_ grid: Grid, row: Int, from column: Int, width: Int) -> String {
        (column..<(column + width)).reduce(into: "") { line, index in
            switch grid[index, row].glyph {
            case .narrow(let character), .wide(let character):
                line.append(character)
            case .continuation:
                break
            }
        }
    }

    private static let rows = [
        FeedRow(name: "NHK", health: .fetched(count: 7), fetching: false),
        FeedRow(name: "BBC World", health: .unchanged(count: 32), fetching: false),
        FeedRow(name: "NPR News", health: .failed(.status(503)), fetching: false),
        FeedRow(name: "The Guardian World", health: .fetched(count: 45), fetching: true),
    ]

    private func state(
        _ article: Article?, paused: Bool = false, fresh: Bool = false, feeds: [FeedRow] = Self.rows
    ) -> StripState {
        StripState(
            article: article, fresh: fresh, position: article == nil ? 0 : 42, count: article == nil ? 0 : 180,
            paused: paused, feeds: feeds, message: "13:25:12  BBC World  32 件  新着 2", clock: clock)
    }

    @Test func stripIsFifteenRowsAndTheFrameLinesUpAtEveryWidth() {
        for columns in [72, 80, 120, 160, 200] {
            let grid = StripRenderer.render(
                state(sample()), size: ScreenSize(columns: columns, rows: 40), theme: .phosphor, traits: traits)
            #expect(grid.size == ScreenSize(columns: columns, rows: 15))
            let layout = StripLayout(columns: columns, glyphs: FrameGlyphs.of(.boxDrawing), theme: .phosphor)
            let divider = layout.inner + 1
            #expect(grid[0, 1].glyph == .narrow("┌") && grid[columns - 1, 1].glyph == .narrow("┐"))
            #expect(grid[divider, 1].glyph == .narrow("┬") && grid[divider, 12].glyph == .narrow("┴"))
            #expect(grid[0, 12].glyph == .narrow("└") && grid[columns - 1, 12].glyph == .narrow("┘"))
            for row in 2...11 {
                #expect(grid[0, row].glyph == .narrow("│"))
                #expect(grid[divider, row].glyph == .narrow("│"))
                #expect(grid[columns - 1, row].glyph == .narrow("│"))
            }
        }
    }

    @Test func articleBlockShowsFeedTimeHeadlineLedeAndLink() {
        let grid = StripRenderer.render(
            state(sample()), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(grid, row: 0).contains("NENE//WIRE"))
        #expect(text(grid, row: 0).contains("2026-10-26 21:47:03 JST"))
        #expect(text(grid, row: 1).contains("[ BBC WORLD ]"))
        #expect(text(grid, row: 1).contains("[ 21:47:03 ]"))
        #expect(text(grid, row: 2).contains("受信 042 · 12:31 UTC"))
        #expect(text(grid, row: 4).contains("北海の洋上風力"))
        #expect(text(grid, row: 6).contains("英国北部の洋上風力発電所で"))
        #expect(text(grid, row: 11).contains("› https://example.com/news/0001"))
        #expect(text(grid, row: 12).contains("[ 042 / 180 ]"))
        #expect(text(grid, row: 13).contains("MSG › 13:25:12  BBC World  32 件  新着 2"))
        #expect(text(grid, row: 14).contains("[042/180]"))
        #expect(text(grid, row: 14).contains("FEED 3/4  取得失敗 1"))
    }

    @Test func pausedAndEmptyStatesSayWhatIsGoingOn() {
        let paused = StripRenderer.render(
            state(sample(), paused: true), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(paused, row: 14).contains("停止中"))
        #expect(text(paused, row: 14).contains("SPC 再開"))
        let failing = [FeedRow(name: "NHK", health: .failed(.status(500)), fetching: false)]
        let empty = StripRenderer.render(
            state(nil, feeds: failing), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(empty, row: 2).contains("記事がありません"))
        #expect(text(empty, row: 14).contains("OFFLINE"))
        let starting = [FeedRow(name: "NHK", health: .pending, fetching: true)]
        let booting = StripRenderer.render(
            state(nil, feeds: starting), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(booting, row: 2).contains("回線を確立中"))
        #expect(text(booting, row: 0).contains("LINK PENDING"))
    }

    @Test func freshArticlesAreMarkedAndTheDataWindowListsEveryFeed() {
        let grid = StripRenderer.render(
            state(sample(), fresh: true), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(grid, row: 2).contains("速報 受信 042"))
        let layout = StripLayout(columns: 120, glyphs: FrameGlyphs.of(.boxDrawing), theme: .phosphor)
        let window = (2...5).map { row in text(grid, row: row, from: layout.inner + 2, width: layout.dataWidth) }
        #expect(window[0].contains("● NHK") && window[0].hasSuffix("7"))
        #expect(window[1].contains("BBC World") && window[1].hasSuffix("32"))
        #expect(window[2].contains("! NPR News") && window[2].hasSuffix("ERR"))
        #expect(window[3].contains("~ The Guardian") && window[3].hasSuffix("..."))
    }

    @Test func tooSmallTerminalGetsOnlyTheMessage() {
        let narrow = StripRenderer.render(
            state(sample()), size: ScreenSize(columns: 60, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(narrow, row: 0).hasPrefix("端末が小さすぎる"))
        let short = StripRenderer.render(
            state(sample()), size: ScreenSize(columns: 120, rows: 10), theme: .phosphor, traits: traits)
        #expect(short.size.rows == 10)
        #expect(text(short, row: 0).hasPrefix("端末が小さすぎる"))
    }

    @Test func asciiFrameUsesOnlyAsciiForTheFrame() {
        let ascii = TerminalTraits(frame: .ascii, colors: .palette256)
        let grid = StripRenderer.render(
            state(sample()), size: ScreenSize(columns: 100, rows: 30), theme: .phosphor, traits: ascii)
        #expect(text(grid, row: 1).hasPrefix("+-["))
        #expect(!text(grid, row: 13).contains("─"))
    }

    @Test func readableColorsMeetContrastOnGroundAndPanel() {
        #expect(Theme.catalog.map(\.name) == ["PHOSPHOR", "AMBER", "CYAN", "MAGENTA"])
        #expect(Theme.named("CYAN").name == "CYAN")
        #expect(Theme.named("nope").name == "PHOSPHOR")
        for theme in Theme.catalog {
            for color in [theme.text, theme.head, theme.accent, theme.dim, theme.warn] {
                #expect(Contrast.ratio(color, theme.ground) >= 4.5, "\(theme.name)")
                #expect(Contrast.ratio(color, theme.panel) >= 4.5, "\(theme.name)")
            }
            #expect(Contrast.ratio(theme.ground, theme.warn) >= 4.5, "\(theme.name) の速報の印")
        }
    }
}
