import NeNeWireCore
import NeNeWireHost

/// 裏での取得（FR-07・FR-13・ADR 0007）。予定（Core の `FetchSchedule`）に従って 1 本ずつ curl を起動し、表示のループが待つ間に出力を集める。
struct Fetcher {
    /// 取り終えた 1 本。
    struct Arrival {
        let feed: Int
        let outcome: FetchOutcome
        let articles: [Article]
    }

    let feeds: [Feed]
    private let environment: [String]
    private(set) var schedule: FetchSchedule
    private var running: (feed: Int, child: RunningChild)?

    init(feeds: [Feed], environment: [String], now: Timestamp) {
        self.feeds = feeds
        self.environment = environment
        schedule = .starting(feeds: feeds.count, at: now)
    }

    /// いま取りに行っているフィード。
    var fetching: Int? {
        running?.feed
    }

    /// 表示のループが一緒に待つ読み口。
    var descriptors: [Int32] {
        running?.child.descriptors ?? []
    }

    /// 走っていなければ、予定の来たフィードを取りに行く。起動できなかったらその場で結果を返す。
    mutating func startIfDue(at now: Timestamp) -> Arrival? {
        guard running == nil, let feed = schedule.due(at: now) else {
            return nil
        }
        switch FeedFetch.start(feeds[feed], validators: schedule.statuses[feed].validators, environment: environment) {
        case .running(let child):
            running = (feed, child)
            return nil
        case .failedToStart(let code):
            return record(FeedFetch.notStarted(code), feed: feed, at: now)
        }
    }

    /// 走っている curl の出力を読めるだけ読み、終わっていれば結果を返す。
    mutating func collect(at now: Timestamp) -> Arrival? {
        guard var current = running else {
            return nil
        }
        guard let result = current.child.pump() else {
            running = current
            return nil
        }
        running = nil
        return record(FeedFetch.interpret(result), feed: current.feed, at: now)
    }

    /// 終了するとき、走っている curl を止める。
    mutating func stop() {
        running?.child.stop()
        running = nil
    }

    private mutating func record(_ outcome: FetchOutcome, feed: Int, at now: Timestamp) -> Arrival {
        let articles: [Article]
        switch outcome {
        case .fetched(let document, _):
            articles = document.items.compactMap { Article.from($0, feed: feeds[feed]) }
        case .notModified, .failed:
            articles = []
        }
        let count = articles.isEmpty ? previousCount(feed) : articles.count
        schedule = schedule.recording(outcome, feed: feed, articles: count, at: now)
        return Arrival(feed: feed, outcome: outcome, articles: articles)
    }

    private func previousCount(_ feed: Int) -> Int {
        switch schedule.statuses[feed].health {
        case .fetched(let count), .unchanged(let count):
            return count
        case .pending, .failed:
            return 0
        }
    }
}
