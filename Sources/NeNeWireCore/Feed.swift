/// フィード: 名前・URL・有効かどうか（FR-07・FR-23）。
public struct Feed: Sendable, Hashable {
    public let name: String
    public let url: FeedURL
    public let enabled: Bool

    private init(name: String, url: FeedURL, enabled: Bool) {
        self.name = name
        self.url = url
        self.enabled = enabled
    }

    /// 名前と URL から作る。名前が空なら nil。
    public static func make(name: String, url: FeedURL, enabled: Bool) -> Feed? {
        let trimmed = name.collapsingSpaces
        return trimmed.isEmpty ? nil : Feed(name: trimmed, url: url, enabled: enabled)
    }

    /// 最初から入れておくフィード（FR-26・ADR 0005）。2026-10-26 に実際に取れて、その日の記事が入っていることを確かめたものだけ。
    public static let defaults: [Feed] = [
        ("NHK", "https://www.nhk.or.jp/rss/news/cat0.xml"),
        ("BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml"),
        ("NPR News", "https://feeds.npr.org/1001/rss.xml"),
        ("The Guardian World", "https://www.theguardian.com/world/rss"),
    ].compactMap { name, raw in
        FeedURL.parse(raw).flatMap { make(name: name, url: $0, enabled: true) }
    }
}
