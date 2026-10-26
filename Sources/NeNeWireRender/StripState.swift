import NeNeWireCore

/// 帯に描く状態（FR-14・FR-15）。合成ルートがループの中で作る。
public struct StripState: Sendable, Hashable {
    /// 表示中の記事。手元に 1 件も無ければ nil。
    let article: Article?
    /// 表示中の記事が、取り直して新しく現れた速報か。
    let fresh: Bool
    /// 一周の中の何件目か（1 から）。
    let position: Int
    /// 一周の件数。
    let count: Int
    /// 一時停止中か。
    let paused: Bool
    /// フィードごとの様子（設定の順）。
    let feeds: [FeedRow]
    /// HUD のメッセージの行に出す 1 行（取得の進み具合など）。
    let message: String
    let clock: WallClock

    /// 状態を作る。
    public init(
        article: Article?, fresh: Bool, position: Int, count: Int, paused: Bool, feeds: [FeedRow], message: String,
        clock: WallClock
    ) {
        self.article = article
        self.fresh = fresh
        self.position = position
        self.count = count
        self.paused = paused
        self.feeds = feeds
        self.message = message
        self.clock = clock
    }

    /// 記事を出せるフィードの数。
    var feedsLive: Int {
        feeds.filter(\.isLive).count
    }
}
