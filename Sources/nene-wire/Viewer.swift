import NeNeWireCore
import NeNeWireRender
import NeNeWireTerminal

/// 常駐して記事を流し続ける 1 本のループ（FR-01・FR-07・FR-12・FR-13・FR-22・ADR 0007・0009・0011）。状態はすべてこの値の中にあり、ループの外へ出ない（ARC-005）。
/// キー入力・取得の curl の出力・次の描画の時刻を、`Console.waitForInput` の 1 か所で待つ。
/// 移植元: NeNe Reversi `Sources/nene-reversi/Screensaver.swift`（コミット dc418eb）の形。
struct Viewer {
    /// 演出の最中に描き直す間隔（毎秒 30 回）と、静かなときの間隔（毎秒 15 回）。
    static let busyFrame: Int32 = 33
    static let calmFrame: Int32 = 66
    /// 接続シーケンスを見せる最短の長さ。
    static let shortestBoot = 2_500

    private let traits: TerminalTraits
    private let clock = ContinuousClock()
    private let launched: ContinuousClock.Instant
    private var fetcher: Fetcher
    private var translator: Translator
    private var rotation: Rotation
    /// いま見せている記事（見せ始めたときの訳で固定する。見せている途中で訳が届いても文面を跳ねさせない）。
    private var shown: Article?
    private var shownUntranslated = false
    private var showtime = Showtime()
    private var booting = true
    private var bootLog: BootLog
    private var paused = false
    private var message = "回線を確立中"
    private var previous: Grid?
    private var settings: Settings
    private let settingsFile: SettingsFile
    private let environment: [String]
    /// `--demo` か（フィードの変更は反映しない）。
    private let demo: Bool
    /// 開いている設定画面。表示の帯なら nil。
    private var session: SettingsSession?
    /// 読み取りの切れ目で途中まで届いた UTF-8 の文字。
    private var keyCarry: [UInt8] = []

    init(
        fetcher: Fetcher, translator: Translator, traits: TerminalTraits, version: String, settings: Settings,
        settingsFile: SettingsFile, environment: [String], demo: Bool, notice: String?
    ) {
        self.fetcher = fetcher
        self.translator = translator
        self.traits = traits
        self.settings = settings
        self.settingsFile = settingsFile
        self.environment = environment
        self.demo = demo
        rotation = .empty(feeds: fetcher.feeds.count)
        launched = clock.now
        bootLog = BootLog(version: version, size: Console.size(), translator: translator.problem)
        if let notice {
            message = notice
        }
    }

    /// 1 件を見せる時間（切り替えの演出を含む・設定）。
    private var interval: Int {
        settings.display.interval * 1_000
    }

    /// `q` か終了のシグナルが来るまで回す。
    mutating func run() {
        while true {
            fetch(at: LocalTime.timestamp())
            let busy = draw()
            let bytes = Console.waitForInput(
                milliseconds: busy ? Self.busyFrame : Self.calmFrame,
                watching: fetcher.descriptors + translator.descriptors + (session?.descriptors ?? []))
            let signals = Console.takeSignals()
            var moved = false
            if session != nil {
                handleSettings(KeyPress.decode(bytes, carry: &keyCarry))
            } else {
                let intents = KeyIntent.decode(bytes)
                if intents.contains(.quit) {
                    stopAll()
                    return
                }
                moved = apply(intents)
            }
            if signals.interrupted {
                stopAll()
                return
            }
            if signals.resized {
                Console.clear()
                previous = nil
            }
            fetch(at: LocalTime.timestamp())
            translate(at: LocalTime.timestamp())
            session?.poll()
            finishBootIfReady()
            if session == nil, !moved, !booting, !paused, showtime.milliseconds >= interval {
                move { $0.advance() }
            }
        }
    }

    private mutating func stopAll() {
        fetcher.stop()
        translator.stop()
        session?.stop()
    }

    /// 設定画面を開く（記事の時計は止める）。
    private mutating func openSettings() {
        session = SettingsSession(settings: settings, file: settingsFile, environment: environment)
        if !paused {
            showtime.pause()
        }
        previous = nil
    }

    /// 設定画面のキーを渡し、保存できた設定を反映し、閉じたら帯に戻る（FR-25: 反映は次の記事から）。
    private mutating func handleSettings(_ keys: [KeyPress]) {
        guard var current = session, !keys.isEmpty else {
            return
        }
        let outcome = current.press(keys)
        session = current
        switch outcome {
        case .stay:
            return
        case .apply(let saved):
            adopt(saved)
        case .applyAndClose(let saved):
            adopt(saved)
            closeSettings()
        case .close:
            closeSettings()
        }
    }

    private mutating func closeSettings() {
        session = nil
        if !paused {
            showtime.resume()
        }
        previous = nil
    }

    /// 保存した設定を反映する。表示の言語が変わったら訳し直し、有効なフィードが変わったら取り直す。
    private mutating func adopt(_ new: Settings) {
        let old = settings
        settings = new
        if new.display.language != old.display.language {
            translator.retarget(new.display.language, keeping: rotation.articles)
        }
        let feeds = new.feeds.filter(\.enabled)
        guard feeds != old.feeds.filter(\.enabled) else {
            return
        }
        guard !demo else {
            message = "デモの間はフィードの変更を反映しない（保存はした）"
            return
        }
        fetcher.stop()
        fetcher = Fetcher(feeds: feeds, environment: environment, now: LocalTime.timestamp())
        rotation = .empty(feeds: feeds.count)
        message = "\(LocalTime.now().time)  フィードを替えた。取り直している"
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
        present()
        showtime.begin(leaving: nil, first: true)
    }

    /// いまの記事を、いまある訳で固定して見せる。
    private mutating func present() {
        shown = rotation.current.map(translator.show)
        shownUntranslated = rotation.current.map(translator.isUntranslated) ?? false
    }

    /// 記事を動かし、前の記事を切り替えの演出に渡す。
    private mutating func move(_ step: (inout Rotation) -> Void) {
        let before = shown
        step(&rotation)
        present()
        showtime.begin(leaving: before, first: false)
    }

    /// 翻訳を進める: 終わった翻訳の結果を受け取り、訳してよい記事があれば訳しに行く。
    private mutating func translate(at now: Timestamp) {
        for report in [translator.collect(at: now), translator.startIfDue(at: now)].compactMap({ $0 }) {
            let time = LocalTime.now().time
            switch report.outcome {
            case .translated:
                message = "\(time)  翻訳  \(report.articles) 件"
            case .unavailable(.notInstalled), .unavailable(.missingModel):
                message = "\(time)  翻訳の手段が無い。install-translator.sh で入れて起動し直すと訳す"
            case .unavailable(.crashed):
                message = "\(time)  翻訳に失敗  \(TranslationQueue.retry / 60) 分後に取り直す"
            }
        }
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
            translator.take(arrival.articles, keeping: rotation.identifiers)
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
            case .settings:
                openSettings()
                return moved
            }
        }
        return moved
    }

    /// いまの状態を描き、前のフレームと違う行だけを 1 回で書く。演出の最中なら true。
    private mutating func draw() -> Bool {
        let theme = Theme.named(settings.display.theme)
        if let session {
            let grid = SettingsRenderer.render(
                session.editor, clock: LocalTime.now(), size: Console.size(), style: (theme, traits))
            Console.write(FrameEncoder.encode(grid, previous: previous, colors: traits.colors))
            previous = grid
            return false
        }
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
            firstEntry: showtime.firstEntry, interval: interval, uptime: uptime / 1_000, syncIn: syncIn)
        let state = StripState(
            article: booting ? nil : shown, fresh: !booting && rotation.isFresh, position: rotation.position,
            count: rotation.count, paused: paused, feeds: rows, message: message, clock: LocalTime.now(),
            motion: motion, log: booting ? bootLog.lines : [], pendingFresh: rotation.pendingFresh,
            untranslated: !booting && shownUntranslated, translator: translator.status, rain: settings.display.rain,
            showOriginal: settings.display.original)
        let grid = StripRenderer.render(state, size: Console.size(), theme: theme, traits: traits)
        Console.write(FrameEncoder.encode(grid, previous: previous, colors: traits.colors))
        previous = grid
        return StripRenderer.isBusy(state)
    }
}
