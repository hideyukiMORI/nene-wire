import NeNeWireCore

/// 帯に描く状態（FR-14・FR-15）。合成ルートがループの中で作る。
public struct StripState: Sendable, Hashable {
    /// 表示中の記事。手元に 1 件も無ければ nil。
    let article: Article?
    /// 何件目か（1 から）。
    let position: Int
    /// 全部で何件か。
    let count: Int
    /// 一時停止中か。
    let paused: Bool
    /// 取れたフィードの数。
    let feedsFetched: Int
    /// 有効なフィードの数。
    let feedsTotal: Int
    let clock: WallClock

    /// 状態を作る。
    public init(
        article: Article?, position: Int, count: Int, paused: Bool, feedsFetched: Int, feedsTotal: Int,
        clock: WallClock
    ) {
        self.article = article
        self.position = position
        self.count = count
        self.paused = paused
        self.feedsFetched = feedsFetched
        self.feedsTotal = feedsTotal
        self.clock = clock
    }
}
