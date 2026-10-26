/// 記事: 表示に使う値（FR-08・FR-14）。フィードの 1 項目から、HTML を除いた見出しと出だしを作る。
public struct Article: Sendable, Hashable {
    public let feedName: String
    public let headline: String
    /// 出だし。要約欄が空か見出しと同じなら nil（見出しだけを出す）。
    public let lede: String?
    public let link: String
    public let published: Timestamp?
    public let identifier: String

    private init(
        feedName: String, headline: String, lede: String?, link: String, published: Timestamp?, identifier: String
    ) {
        self.feedName = feedName
        self.headline = headline
        self.lede = lede
        self.link = link
        self.published = published
        self.identifier = identifier
    }

    /// フィードの 1 項目から作る。見出しが空なら nil。
    public static func from(_ item: FeedItem, feed: Feed) -> Article? {
        let headline = PlainText.from(html: item.title)
        guard !headline.isEmpty else {
            return nil
        }
        let lede = Lede.make(paragraphs: PlainText.paragraphs(html: item.summary), headline: headline)
        return Article(
            feedName: feed.name, headline: headline, lede: lede, link: item.link, published: item.published,
            identifier: item.identifier.isEmpty ? item.link : item.identifier)
    }
}
