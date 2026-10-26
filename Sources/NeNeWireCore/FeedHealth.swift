/// フィードのいまの様子（HUD の DATA の窓に出す・FR-15）。
public enum FeedHealth: Sendable, Hashable {
    /// まだ取っていない。
    case pending
    /// 取れた（記事の件数）。
    case fetched(count: Int)
    /// 更新が無かった（HTTP 304）。前に取った記事を使い続ける。
    case unchanged(count: Int)
    /// 取れなかった。前に取った記事があれば使い続ける。
    case failed(FetchFailure)
}
