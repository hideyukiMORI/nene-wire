import NeNeWireCore
import NeNeWireRender
import NeNeWireTerminal

/// 常駐して記事を流し続ける 1 本のループ（FR-01・FR-07・FR-12・FR-13・FR-22・ADR 0007）。状態はすべてこの値の中にあり、ループの外へ出ない（ARC-005）。
/// キー入力・取得の curl の出力・締め切り・秒の変わり目を、`Console.waitForInput` の 1 か所で待つ。
/// 移植元: NeNe Reversi `Sources/nene-reversi/Screensaver.swift`（コミット dc418eb）の形。
struct Viewer {
    /// 1 件を見せる時間（ADR 0006）。
    static let interval: Duration = .seconds(12)

    private let traits: TerminalTraits
    private let clock = ContinuousClock()
    private var fetcher: Fetcher
    private var rotation: Rotation
    private var paused = false
    private var message = "回線を確立中"
    private var previous: Grid?

    init(fetcher: Fetcher, traits: TerminalTraits) {
        self.fetcher = fetcher
        self.traits = traits
        rotation = .empty(feeds: fetcher.feeds.count)
    }

    /// `q` か終了のシグナルが来るまで回す。
    mutating func run() {
        var deadline = clock.now + Self.interval
        while true {
            fetch(at: LocalTime.timestamp())
            draw()
            let untilDeadline = paused || rotation.current == nil ? Int32.max : milliseconds(until: deadline)
            let bytes = Console.waitForInput(
                milliseconds: min(untilDeadline, LocalTime.millisecondsToNextSecond()), watching: fetcher.descriptors)
            let intents = KeyIntent.decode(bytes)
            let signals = Console.takeSignals()
            if signals.interrupted || intents.contains(.quit) {
                fetcher.stop()
                return
            }
            if signals.resized {
                Console.clear()
                previous = nil
            }
            let hadArticle = rotation.current != nil
            fetch(at: LocalTime.timestamp())
            if !hadArticle, rotation.current != nil {
                deadline = clock.now + Self.interval
            }
            if apply(intents) {
                deadline = clock.now + Self.interval
            } else if !paused, rotation.current != nil, clock.now >= deadline {
                rotation.advance()
                deadline = clock.now + Self.interval
            }
        }
    }

    /// 取得を進める: 終わった curl の結果を受け取り、予定の来たフィードを取りに行く。
    private mutating func fetch(at now: Timestamp) {
        if let arrival = fetcher.collect(at: now) {
            receive(arrival)
        }
        if let arrival = fetcher.startIfDue(at: now) {
            receive(arrival)
        }
        if let feed = fetcher.fetching {
            message = "\(LocalTime.now().time)  取得中  \(fetcher.feeds[feed].name) …"
        }
    }

    private mutating func receive(_ arrival: Fetcher.Arrival) {
        let name = fetcher.feeds[arrival.feed].name
        let time = LocalTime.now().time
        switch arrival.outcome {
        case .fetched:
            let before = rotation.pendingFresh
            rotation.replace(feed: arrival.feed, with: arrival.articles)
            let arrived = rotation.pendingFresh - before
            message = "\(time)  \(name)  \(arrival.articles.count) 件" + (arrived > 0 ? "  新着 \(arrived)" : "")
        case .notModified:
            message = "\(time)  \(name)  更新なし"
        case .failed(let failure):
            let wait = fetcher.schedule.statuses[arrival.feed].failures
            message =
                "\(time)  \(name)  \(FeedFetch.describe(failure))  \(FetchSchedule.backoff(failures: wait) / 60) 分後に取り直す"
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
                rotation.advance()
                moved = true
            case .previous:
                rotation.goBack()
                moved = true
            }
        }
        return moved
    }

    /// いまの状態を描き、前のフレームと違う行だけを 1 回で書く。
    private mutating func draw() {
        let rows = fetcher.feeds.indices.map { index in
            FeedRow(
                name: fetcher.feeds[index].name, health: fetcher.schedule.statuses[index].health,
                fetching: fetcher.fetching == index)
        }
        let state = StripState(
            article: rotation.current, fresh: rotation.isFresh, position: rotation.position, count: rotation.count,
            paused: paused, feeds: rows, message: message, clock: LocalTime.now())
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
