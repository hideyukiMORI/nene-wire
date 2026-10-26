/// フィードを取りに行った結果。
public enum FetchOutcome: Sendable, Hashable {
    /// 取れた（応答のヘッダは、次の条件付きの取得の手がかりに使う）。
    case fetched(FeedDocument, headers: [HTTPHeader])
    /// 更新が無い（HTTP 304）。
    case notModified
    case failed(FetchFailure)
}
