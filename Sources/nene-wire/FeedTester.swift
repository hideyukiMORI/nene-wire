import NeNeWireCore
import NeNeWireHost

/// 設定画面の「試す」（FR-23）。選んだフィードを 1 回だけ取り、何件・何語・何秒か、失敗ならその理由を 1 行にする。
struct FeedTester {
    /// 試している最中の 1 本。
    private struct Probe {
        let feed: Feed
        var child: RunningChild
        let started: ContinuousClock.Instant
    }

    private let clock = ContinuousClock()
    private let environment: [String]
    private var running: Probe?

    init(environment: [String]) {
        self.environment = environment
    }

    var descriptors: [Int32] {
        running?.child.descriptors ?? []
    }

    /// 試し始める。起動できなければその場で結果の 1 行を返す。
    mutating func start(_ feed: Feed) -> String? {
        stop()
        switch FeedFetch.start(feed, validators: .none, environment: environment) {
        case .running(let child):
            running = Probe(feed: feed, child: child, started: clock.now)
            return nil
        case .failedToStart(let code):
            return "\(feed.name)  curl を起動できない（errno \(code)）  NG"
        }
    }

    /// 終わっていれば結果の 1 行。
    mutating func collect() -> String? {
        guard var current = running else {
            return nil
        }
        guard let result = current.child.pump() else {
            running = current
            return nil
        }
        running = nil
        let seconds = Showtime.milliseconds(clock.now - current.started)
        let time = "\(seconds / 1_000).\(String(seconds % 1_000 / 10).leftPadded(2)) 秒"
        switch FeedFetch.interpret(result) {
        case .fetched(let document, _):
            let articles = document.items.compactMap { Article.from($0, feed: current.feed) }
            return "\(current.feed.name)  \(articles.count) 件 · \(Self.language(of: articles)) · \(time)  OK"
        case .notModified:
            return "\(current.feed.name)  更新なし · \(time)  OK"
        case .failed(let failure):
            return "\(current.feed.name)  \(FeedFetch.describe(failure))  NG"
        }
    }

    mutating func stop() {
        running?.child.stop()
        running = nil
    }

    /// 記事の言語の多数決（判定できなければ「不明」）。
    private static func language(of articles: [Article]) -> String {
        let guesses = articles.compactMap { LanguageGuess.of($0.headline) }
        let counts = Dictionary(grouping: guesses, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? "不明"
    }
}

extension String {
    /// 左を 0 で埋めた文字列。
    func leftPadded(_ width: Int) -> String {
        String(repeating: "0", count: max(width - count, 0)) + self
    }
}
