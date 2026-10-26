/// フィードを取れなかった理由（FR-15 で状態の帯に出す）。
public enum FetchFailure: Sendable, Hashable {
    /// curl が失敗した（名前解決・接続・時間切れなど）。curl の終了コードと、標準エラーの 1 行目。
    case transport(code: Int32, message: String)
    /// HTTP の状態が 200 でも 304 でもない。
    case status(Int)
    /// curl の出力を HTTP の応答として読めない。
    case unreadable(HTTPRejection)
    /// フィードとして読めない。
    case notFeed(FeedRejection)
}
