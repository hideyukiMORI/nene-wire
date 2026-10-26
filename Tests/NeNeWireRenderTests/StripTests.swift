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

    private func state(_ article: Article?, paused: Bool = false) -> StripState {
        StripState(
            article: article, position: article == nil ? 0 : 42, count: article == nil ? 0 : 180, paused: paused,
            feedsFetched: article == nil ? 0 : 3, feedsTotal: 4, clock: clock)
    }

    @Test func stripIsFifteenRowsAndTheFrameLinesUpAtEveryWidth() {
        for columns in [72, 80, 120, 160, 200] {
            let grid = StripRenderer.render(
                state(sample()), size: ScreenSize(columns: columns, rows: 40), theme: .phosphor, traits: traits)
            #expect(grid.size == ScreenSize(columns: columns, rows: 15))
            let layout = StripLayout(columns: columns, glyphs: FrameGlyphs.of(.boxDrawing), theme: .phosphor)
            let divider = layout.inner + 1
            #expect(grid[0, 1].glyph == .narrow("┌") && grid[columns - 1, 1].glyph == .narrow("┐"))
            #expect(grid[divider, 1].glyph == .narrow("┬") && grid[divider, 13].glyph == .narrow("┴"))
            #expect(grid[0, 13].glyph == .narrow("└") && grid[columns - 1, 13].glyph == .narrow("┘"))
            for row in 2...12 {
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
        #expect(text(grid, row: 12).contains("› https://example.com/news/0001"))
        #expect(text(grid, row: 13).contains("[ 042 / 180 ]"))
        #expect(text(grid, row: 14).contains("[042/180]"))
        #expect(text(grid, row: 14).contains("FEED 3/4  取得失敗 1"))
    }

    @Test func pausedAndEmptyStatesSayWhatIsGoingOn() {
        let paused = StripRenderer.render(
            state(sample(), paused: true), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(paused, row: 14).contains("停止中"))
        #expect(text(paused, row: 14).contains("SPC 再開"))
        let empty = StripRenderer.render(
            state(nil), size: ScreenSize(columns: 120, rows: 30), theme: .phosphor, traits: traits)
        #expect(text(empty, row: 2).contains("記事がありません"))
        #expect(text(empty, row: 14).contains("OFFLINE"))
        #expect(text(empty, row: 0).contains("LINK LOST"))
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
        let theme = Theme.phosphor
        for color in [theme.text, theme.head, theme.accent, theme.dim] {
            #expect(Contrast.ratio(color, theme.ground) >= 4.5)
            #expect(Contrast.ratio(color, theme.panel) >= 4.5)
        }
    }
}
