/// 保存した記事の欄（読み戻すときに `Article.restored` へ渡す・ADR 0014）。
public struct ArticleFields: Sendable, Hashable {
    public let feedName: String
    public let headline: String
    public let lede: String?
    public let link: String
    public let published: Timestamp?
    public let identifier: String

    /// 組を作る。
    public init(
        feedName: String, headline: String, lede: String?, link: String, published: Timestamp?, identifier: String
    ) {
        self.feedName = feedName
        self.headline = headline
        self.lede = lede
        self.link = link
        self.published = published
        self.identifier = identifier
    }
}
