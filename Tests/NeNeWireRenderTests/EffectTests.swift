import NeNeWireCore
import Testing

@testable import NeNeWireRender

/// 演出（ADR 0009）。どれも「時計（Motion）と種」だけから決まるので、時刻を決めて格子の中身を確かめる。
struct EffectTests {
    private let clock = WallClock(year: 2026, month: 10, day: 26, hour: 21, minute: 47, second: 3, zone: "JST")
    private let box = TerminalTraits(frame: .boxDrawing, colors: .trueColor)
    private let size = ScreenSize(columns: 120, rows: 30)
    private let feeds = [
        FeedRow(name: "NEON TIMES", health: .fetched(count: 3), fetching: false),
        FeedRow(name: "GRID DAILY", health: .fetched(count: 2), fetching: false),
    ]

    private func article(_ headline: String, _ id: String) -> Article? {
        let xml = """
            <rss version="2.0"><channel><title>t</title><item><title>\(headline)</title>
            <link>https://example.com/\(id)</link><guid>\(id)</guid><pubDate>Mon, 26 Oct 2026 12:31:00 GMT</pubDate>
            <description>英国北部の洋上風力発電所で、陸上の送電網の整備が追いつかず、全面稼働が来年春までずれ込む見通しとなった。</description>
            </item></channel></rss>
            """
        guard case .parsed(let document) = FeedParser.parse(xml), let item = document.items.first,
            let url = FeedURL.parse("https://example.com/feed"),
            let feed = Feed.make(name: "NEON TIMES", url: url, enabled: true)
        else {
            return nil
        }
        return Article.from(item, feed: feed)
    }

    private func motion(_ article: Int, seed: UInt64 = 7, leaving: Article? = nil, first: Bool = false) -> Motion {
        Motion(
            article: article, global: 5_000, seed: seed, leaving: leaving, firstEntry: first, interval: 12_000,
            uptime: 3_725, syncIn: 754)
    }

    /// 起動してからの時刻だけを変えた時計。
    private func motion(_ article: Int, global: Int) -> Motion {
        Motion(
            article: article, global: global, seed: 7, leaving: nil, firstEntry: false, interval: 12_000, uptime: 3_725,
            syncIn: 754)
    }

    private func state(_ article: Article?, fresh: Bool = false, motion: Motion, log: [LogLine] = []) -> StripState {
        StripState(
            article: article, fresh: fresh, position: 1, count: 6, paused: false, feeds: feeds, message: "msg",
            clock: clock, motion: motion, log: log)
    }

    private func render(_ state: StripState, traits: TerminalTraits? = nil) -> Grid {
        StripRenderer.render(state, size: size, theme: .phosphor, traits: traits ?? box)
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

    private func body(_ grid: Grid) -> String {
        (2...11).map { text(grid, row: $0) }.joined(separator: "\n")
    }

    @Test func theSameClockGivesTheSameFrame() throws {
        let story = try #require(article("北海の洋上風力、送電網の遅れ", "a1"))
        let first = render(state(story, motion: motion(900)))
        #expect(render(state(story, motion: motion(900))) == first)
        #expect(render(state(story, motion: motion(900, seed: 8))) != first)
    }

    @Test func charactersSpinBeforeTheyLockAndThenStayPut() throws {
        let story = try #require(article("北海の洋上風力、送電網の遅れ", "a1"))
        for seed in UInt64(0)..<12 {
            let spinning = render(state(story, motion: motion(150, seed: seed)))
            #expect(!body(spinning).contains("北海の洋上風力"))
            #expect(text(spinning, row: 2).contains("復号中"))
            let settled = render(state(story, motion: motion(Choreography.entry + 300, seed: seed)))
            #expect(body(settled).contains("北海の洋上風力、送電網の遅れ"))
            #expect(text(settled, row: 2).contains("受信 001"))
        }
    }

    @Test func everySpinOrderLocksWithinTheEntry() {
        let cell = BodyCell(
            column: 90, row: 11, character: "あ", wide: true, foreground: Theme.phosphor.text,
            background: Theme.phosphor.ground)
        for order in SpinOrder.allCases {
            for count in [1, 40, 400, 2_000] {
                let plan = SpinEffect.Plan(count: count, inner: 96, order: order, seed: 3)
                for index in [0, count / 2, count - 1] {
                    let (appear, lock) = SpinEffect.times(of: index, cell: cell, plan: plan)
                    #expect(appear <= lock)
                    #expect(lock <= Choreography.entry)
                }
            }
        }
    }

    @Test func theLeavingStoryFallsOrIsScannedAwayBeforeTheNextOneSpinsIn() throws {
        let old = try #require(article("北海の洋上風力、送電網の遅れ", "a1"))
        let new = try #require(article("湾岸エリアで通信障害", "a2"))
        for seed in UInt64(0)..<8 {
            let start = render(state(new, motion: motion(0, seed: seed, leaving: old)))
            #expect(body(start).contains("北海"))
            #expect(!body(start).contains("湾岸エリア"))
            let late = render(state(new, motion: motion(Choreography.transition - 1, seed: seed, leaving: old)))
            #expect(!body(late).contains("北海の洋上風力"))
        }
    }

    @Test func breakingNewsSoundsTheAlarmFirst() throws {
        let story = try #require(article("湾岸エリアで通信障害", "a3"))
        let alarm = render(state(story, fresh: true, motion: motion(500)))
        #expect(text(alarm, row: 0).contains("!! INTERCEPT !!"))
        #expect(text(alarm, row: 1).contains("速報 // BREAKING"))
        #expect(text(alarm, row: 6).contains("INTERCEPT"))
        #expect(text(alarm, row: 13).contains("優先度 ALPHA"))
        let landed = render(state(story, fresh: true, motion: motion(Choreography.alarm + Choreography.entry + 100)))
        #expect(text(landed, row: 2).contains("速報"))
        #expect(body(landed).contains("湾岸エリアで通信障害"))
    }

    @Test func aGhostBurstsThroughTheHoldTwice() throws {
        let story = try #require(article("北海の洋上風力、送電網の遅れ", "a1"))
        let clock = motion(0)
        let bursts = Choreography.bursts(clock)
        #expect(bursts.count == 2)
        #expect(bursts.allSatisfy { $0 > Choreography.entry && $0 + Choreography.burst < clock.interval })
        let glitch = render(state(story, motion: motion(bursts[0] + 50)))
        #expect(text(glitch, row: 0).contains("S1GN4L"))
        #expect(text(glitch, row: 13).contains("ゴーストを検知"))
        let calm = render(state(story, motion: motion(bursts[0] - 50)))
        #expect(!text(calm, row: 0).contains("S1GN4L"))
        #expect(!StripRenderer.isBusy(state(story, motion: motion(bursts[0] - 50))))
        #expect(StripRenderer.isBusy(state(story, motion: motion(bursts[0] + 50))))
    }

    @Test func theFirstStoryTracesTheFrameFirst() throws {
        let story = try #require(article("北海の洋上風力、送電網の遅れ", "a1"))
        let tracing = render(state(story, motion: motion(Choreography.trace / 4, first: true)))
        #expect(text(tracing, row: 1).hasPrefix("┌"))
        #expect(!text(tracing, row: 12).contains("└"))
        let traced = render(state(story, motion: motion(Choreography.trace + Choreography.entry + 10, first: true)))
        #expect(text(traced, row: 12).hasPrefix("└"))
    }

    @Test func theBootSequenceTypesTheLogAndDumpsHex() {
        let log = [LogLine(text: "> 回線 NEON TIMES  …  3 件  [ OK ]", at: 0), LogLine(text: "> 回線を確立中 …", at: 4_000)]
        let early = render(state(nil, motion: motion(0, global: 200), log: log))
        #expect(!body(early).contains("[ OK ]"))
        let later = render(state(nil, motion: motion(0, global: 3_000), log: log))
        #expect(body(later).contains("> 回線 NEON TIMES  …  3 件  [ OK ]"))
        #expect(!body(later).contains("回線を確立中"))
        #expect(text(later, row: 1).contains("BOOT SEQUENCE"))
        let dump = text(later, row: 11).suffix(20)
        #expect(dump.filter(\.isHexDigit).count >= 12)
    }

    @Test func theHudBreathes() throws {
        let story = try #require(article("北海の洋上風力、送電網の遅れ", "a1"))
        let hold = render(state(story, motion: motion(Choreography.entry + 500)))
        #expect(text(hold, row: 10).contains("SYNC 12:34"))
        #expect(text(hold, row: 11).contains("UP  01:02:05"))
        #expect(text(hold, row: 12).hasPrefix("└━"))
        let frames = Set(
            (0..<20).map { render(state(story, motion: motion(Choreography.entry + 500, global: $0 * 120))) })
        #expect(frames.count > 10)
    }

    @Test func asciiTerminalsGetAsciiEffects() throws {
        let story = try #require(article("湾岸エリアで通信障害", "a3"))
        let ascii = TerminalTraits(frame: .ascii, colors: .palette256)
        let alarm = render(state(story, fresh: true, motion: motion(500)), traits: ascii)
        for row in 0..<15 {
            #expect(!text(alarm, row: row).contains { "▚▞█▓▒░━▮▯◜◝◞◟─│┌┐└┘┬┴".contains($0) })
        }
    }

    @Test func theMarqueeAlwaysFillsItsWidthExactly() {
        for offset in 0..<120 {
            #expect(CellWidth.of(InterceptEffect.marquee(width: 95, offset: offset)) == 95)
        }
    }

    @Test func theHeaderKeepsTheTimeOnNarrowTerminals() throws {
        let story = try #require(article("北海", "a1"))
        for columns in [72, 80, 100] {
            let grid = StripRenderer.render(
                state(story, motion: .still), size: ScreenSize(columns: columns, rows: 30), theme: .phosphor,
                traits: box)
            #expect(text(grid, row: 0).contains("21:47:03"))
        }
    }

    @Test func translatedStoriesShowTheOriginalHeadlineAndTheTranslatorState() throws {
        let english = try #require(article("Night trains return to the coastal line", "e1"))
        let shown = english.translated(Translation(headline: "夜行列車が海岸線に戻る", lede: "夜行便が再開する。"))
        let translated = render(
            StripState(
                article: shown, fresh: false, position: 1, count: 6, paused: false, feeds: feeds, message: "m",
                clock: clock, translator: .ready(route: "en>ja", pending: 7, busy: true)))
        #expect(body(translated).contains("夜行列車が海岸線に戻る"))
        #expect(text(translated, row: 10).contains("原文 Night trains return to the coastal line"))
        #expect(text(translated, row: 14).contains("TRANS en>ja ● 待ち 7"))
        let raw = render(
            StripState(
                article: english, fresh: false, position: 1, count: 6, paused: false, feeds: feeds, message: "m",
                clock: clock, untranslated: true, translator: .off))
        #expect(text(raw, row: 2).contains("未翻訳"))
        #expect(!text(raw, row: 10).contains("原文"))
        #expect(text(raw, row: 14).contains("TRANS 未導入"))
    }
}
