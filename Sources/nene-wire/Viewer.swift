import NeNeWireCore
import NeNeWireRender
import NeNeWireTerminal

/// 記事を一件ずつ見せる 1 本のループ（FR-01・FR-12・FR-22・ADR 0006）。状態はすべてこの値の中にあり、ループの外へ出ない（ARC-005）。
/// 移植元: NeNe Reversi `Sources/nene-reversi/Screensaver.swift`（コミット dc418eb）の形。
struct Viewer {
    /// 1 件を見せる時間（ADR 0006）。
    static let interval: Duration = .seconds(12)

    private let articles: [Article]
    private let feedsFetched: Int
    private let feedsTotal: Int
    private let traits: TerminalTraits
    private let clock = ContinuousClock()
    private var index = 0
    private var paused = false
    private var previous: Grid?

    init(articles: [Article], feedsFetched: Int, feedsTotal: Int, traits: TerminalTraits) {
        self.articles = articles
        self.feedsFetched = feedsFetched
        self.feedsTotal = feedsTotal
        self.traits = traits
    }

    /// `q` か終了のシグナルが来るまで回す。
    mutating func run() {
        Console.reserve(rows: stripRows(), again: false)
        var deadline = clock.now + Self.interval
        draw()
        while true {
            let untilDeadline = paused ? Int32.max : milliseconds(until: deadline)
            let bytes = Console.waitForInput(milliseconds: min(untilDeadline, LocalTime.millisecondsToNextSecond()))
            let intents = KeyIntent.decode(bytes)
            let signals = Console.takeSignals()
            if signals.interrupted || intents.contains(.quit) {
                return
            }
            if signals.resized {
                Console.reserve(rows: stripRows(), again: true)
                previous = nil
            }
            if apply(intents) || (!paused && clock.now >= deadline) {
                if !intents.contains(.previous), !intents.contains(.next) {
                    step(by: 1)
                }
                deadline = clock.now + Self.interval
            }
            draw()
        }
    }

    /// キーの意図を当てる。記事を動かしたら true（締め切りを数え直す）。
    private mutating func apply(_ intents: [KeyIntent]) -> Bool {
        var moved = false
        for intent in intents {
            switch intent {
            case .quit:
                return moved
            case .togglePause:
                paused.toggle()
            case .next:
                step(by: 1)
                moved = true
            case .previous:
                step(by: -1)
                moved = true
            }
        }
        return moved
    }

    /// 最後まで行ったら最初へ、最初より前は最後へ回る（FR-12）。
    private mutating func step(by delta: Int) {
        guard !articles.isEmpty else {
            return
        }
        index = ((index + delta) % articles.count + articles.count) % articles.count
    }

    private func stripRows() -> Int {
        min(StripRenderer.height, max(Console.size().rows, 1))
    }

    /// いまの状態を描き、前のフレームと違う行だけを 1 回で書く。
    private mutating func draw() {
        let state = StripState(
            article: articles.isEmpty ? nil : articles[index], position: articles.isEmpty ? 0 : index + 1,
            count: articles.count, paused: paused, feedsFetched: feedsFetched, feedsTotal: feedsTotal,
            clock: LocalTime.now())
        let grid = StripRenderer.render(state, size: Console.size(), theme: .phosphor, traits: traits)
        Console.write(FrameEncoder.encode(grid, previous: previous, colors: traits.colors))
        previous = grid
    }

    /// 締め切りまでのミリ秒（過ぎていれば 0）。
    private func milliseconds(until instant: ContinuousClock.Instant) -> Int32 {
        let (seconds, attoseconds) = (instant - clock.now).components
        let total = seconds * 1000 + attoseconds / 1_000_000_000_000_000
        return Int32(clamping: max(total, 0))
    }
}
