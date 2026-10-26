import NeNeWireCore

/// 演出の時計（ADR 0009）。合成ルートが時計と乱数を読んで作り、Render はこの値から格子を作る。
public struct Motion: Sendable, Hashable {
    /// いまの記事を見せ始めてからのミリ秒（切り替えの演出を含む）。
    let article: Int
    /// 起動してからのミリ秒（常時の演出に使う）。
    let global: Int
    /// 記事ごとの種（くるくるの止まり方・切り替えの種類・ノイズの時刻を決める）。
    let seed: UInt64
    /// 切り替えで消えていく前の記事。
    let leaving: Article?
    /// 起動して最初の記事（枠を描く演出から始める）。
    let firstEntry: Bool
    /// 1 件を見せる時間（ミリ秒）。
    let interval: Int
    /// 稼働時間（秒）。
    let uptime: Int
    /// 次の取得までの秒数。取りに行っている最中などで分からなければ nil。
    let syncIn: Int?

    /// 時計を作る。
    public init(
        article: Int, global: Int, seed: UInt64, leaving: Article?, firstEntry: Bool, interval: Int, uptime: Int,
        syncIn: Int?
    ) {
        self.article = article
        self.global = global
        self.seed = seed
        self.leaving = leaving
        self.firstEntry = firstEntry
        self.interval = interval
        self.uptime = uptime
        self.syncIn = syncIn
    }

    /// 演出の済んだ、止まった時計（テストと静止画用）。
    public static let still = Motion(
        article: 1_000_000_000, global: 0, seed: 0, leaving: nil, firstEntry: false, interval: 12_000, uptime: 0,
        syncIn: nil)
}
