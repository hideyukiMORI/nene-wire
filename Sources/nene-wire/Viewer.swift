import NeNeWireCore
import NeNeWireRender
import NeNeWireTerminal

/// 常駐して記事を流し続ける 1 本のループ（FR-01・FR-07・FR-12・FR-13・FR-22・ADR 0007・0009）。状態はすべてこの値の中にあり、ループの外へ出ない（ARC-005）。
/// キー入力・取得の curl の出力・次の描画の時刻を、`Console.waitForInput` の 1 か所で待つ。
/// 移植元: NeNe Reversi `Sources/nene-reversi/Screensaver.swift`（コミット dc418eb）の形。
struct Viewer {
    /// 1 件を見せる時間（切り替えの演出を含む・ADR 0006）。
    static let interval = 12_000
    /// 演出の最中に描き直す間隔（毎秒 30 回）と、静かなときの間隔（毎秒 15 回）。
    static let busyFrame: Int32 = 33
    static let calmFrame: Int32 = 66
    /// 接続シーケンスを見せる最短の長さ。
    static let shortestBoot = 2_500

    private let traits: TerminalTraits
    private let clock = ContinuousClock()
    private let launched: ContinuousClock.Instant
    private var fetcher: Fetcher
    private var rotation: Rotation
    private var showtime = Showtime()
    private var booting = true
    private var bootLog: BootLog
    private var paused = false
    private var message = "回線を確立中"
    private var previous: Grid?

    init(fetcher: Fetcher, traits: TerminalTraits, version: String) {
        self.fetcher = fetcher
        self.traits = traits
        rotation = .empty(feeds: fetcher.feeds.count)
        launched = clock.now
        bootLog = BootLog(version: version, size: Console.size())
    }

    /// `q` か終了のシグナルが来るまで回す。
    mutating func run() {
        while true {
            fetch(at: LocalTime.timestamp())
            let busy = draw()
            let bytes = Console.waitForInput(
                milliseconds: busy ? Self.busyFrame : Self.calmFrame, watching: fetcher.descriptors)
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
            fetch(at: LocalTime.timestamp())
            finishBootIfReady()
            if !apply(intents), !booting, !paused, showtime.milliseconds >= Self.interval {
                move { $0.advance() }
            }
        }
    }

    private var uptime: Int {
        Showtime.milliseconds(clock.now - launched)
    }

    /// 最初の記事が届き、ブートログを打ち終えたら、枠をなぞって最初の記事を見せ始める。
    private mutating func finishBootIfReady() {
        guard booting, rotation.current != nil, uptime >= max(Self.shortestBoot, bootLog.typedBy) else {
            return
        }
        booting = false
        showtime.begin(leaving: nil, first: true)
    }

    /// 記事を動かし、前の記事を切り替えの演出に渡す。
    private mutating func move(_ step: (inout Rotation) -> Void) {
        let before = rotation.current
        step(&rotation)
        showtime.begin(leaving: before, first: false)
    }

    /// 取得を進める: 終わった curl の結果を受け取り、予定の来たフィードを取りに行く。
    /// 結果を受け取ったら、その結果をメッセージの行に残す（すぐ次のフィードを取りに行っても「取得中」で上書きしない。
    /// 取りに行っている最中であることは DATA の窓の印で分かる）。
    private mutating func fetch(at now: Timestamp) {
        var received = false
        if let arrival = fetcher.collect(at: now) {
            receive(arrival)
            received = true
        }
        let wasFetching = fetcher.fetching
        if let arrival = fetcher.startIfDue(at: now) {
            receive(arrival)
            received = true
        }
        if !received, wasFetching == nil, let feed = fetcher.fetching {
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
        if booting {
            bootLog.record(arrival, name: name, at: uptime)
            if !fetcher.schedule.statuses.contains(where: { $0.health == .pending }) {
                bootLog.finish(at: uptime)
            }
        }
    }

    /// キーの意図を当てる。記事を動かしたら true。
    private mutating func apply(_ intents: [KeyIntent]) -> Bool {
        var moved = false
        for intent in intents {
            switch intent {
            case .quit:
                return moved
            case .togglePause:
                paused.toggle()
                if paused {
                    showtime.pause()
                } else {
                    showtime.resume()
                }
            case .next:
                guard !booting else {
                    continue
                }
                move { $0.advance() }
                moved = true
            case .previous:
                guard !booting else {
                    continue
                }
                move { $0.goBack() }
                moved = true
            }
        }
        return moved
    }

    /// いまの状態を描き、前のフレームと違う行だけを 1 回で書く。演出の最中なら true。
    private mutating func draw() -> Bool {
        let rows = fetcher.feeds.indices.map { index in
            FeedRow(
                name: fetcher.feeds[index].name, health: fetcher.schedule.statuses[index].health,
                fetching: fetcher.fetching == index)
        }
        let syncIn =
            fetcher.fetching == nil
            ? fetcher.schedule.nextDue.map { max(Int($0.seconds - LocalTime.timestamp().seconds), 0) } : nil
        let motion = Motion(
            article: showtime.milliseconds, global: uptime, seed: showtime.seed, leaving: showtime.leaving,
            firstEntry: showtime.firstEntry, interval: Self.interval, uptime: uptime / 1_000, syncIn: syncIn)
        let state = StripState(
            article: booting ? nil : rotation.current, fresh: !booting && rotation.isFresh, position: rotation.position,
            count: rotation.count, paused: paused, feeds: rows, message: message, clock: LocalTime.now(),
            motion: motion, log: booting ? bootLog.lines : [], pendingFresh: rotation.pendingFresh)
        let grid = StripRenderer.render(state, size: Console.size(), theme: .phosphor, traits: traits)
        Console.write(FrameEncoder.encode(grid, previous: previous, colors: traits.colors))
        previous = grid
        return StripRenderer.isBusy(state)
    }
}
