/// 1 本のフィードの保存（ADR 0014）: URL・条件付きの取得の手がかり・最後に取れた記事。
public struct FeedSnapshot: Sendable, Hashable {
    public let url: String
    public let validators: Validators
    public let articles: [Article]

    /// 組を作る。
    public init(url: String, validators: Validators, articles: [Article]) {
        self.url = url
        self.validators = validators
        self.articles = articles
    }
}
