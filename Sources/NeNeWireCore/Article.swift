/// 記事: 表示に使う値（FR-08・FR-14）。フィードの 1 項目から、HTML を除いた見出しと出だしを作る。
public struct Article: Sendable, Hashable {
    public let feedName: String
    public let headline: String
    /// 出だし。要約欄が空か見出しと同じなら nil（見出しだけを出す）。
    public let lede: String?
    public let link: String
    public let published: Timestamp?
    public let identifier: String
    /// 翻訳したときだけ、原文の見出し（FR-14）。
    public let originalHeadline: String?

    private init(
        feedName: String, headline: String, lede: String?, link: String, published: Timestamp?, identifier: String,
        originalHeadline: String? = nil
    ) {
        self.feedName = feedName
        self.headline = headline
        self.lede = lede
        self.link = link
        self.published = published
        self.identifier = identifier
        self.originalHeadline = originalHeadline
    }

    /// 保存した記事を読み戻す（ADR 0014）。見出しか識別子が空なら nil。
    public static func restored(_ fields: ArticleFields) -> Article? {
        guard !fields.headline.isEmpty, !fields.identifier.isEmpty else {
            return nil
        }
        return Article(
            feedName: fields.feedName, headline: fields.headline, lede: fields.lede, link: fields.link,
            published: fields.published, identifier: fields.identifier)
    }

    /// 見出しと出だしを訳したもの（原文の見出しを残す）。
    public func translated(_ translation: Translation) -> Article {
        Article(
            feedName: feedName, headline: translation.headline, lede: translation.lede ?? lede, link: link,
            published: published, identifier: identifier, originalHeadline: headline)
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
