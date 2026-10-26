/// 記事と訳の保存（FR-11・ADR 0014）。フィードごとの最後に取れた記事と手がかり、表示の言語ごとの訳の控え。
public struct Archive: Sendable, Hashable {
    /// 記事を残す日数（FR-11: 1 週間程度）。
    public static let retentionDays: Int64 = 7

    public let feeds: [FeedSnapshot]
    /// 表示の言語 → 記事の識別子 → 訳。
    public let translations: [String: [String: Translation]]

    /// 組を作る。
    public init(feeds: [FeedSnapshot], translations: [String: [String: Translation]]) {
        self.feeds = feeds
        self.translations = translations
    }

    /// 空の保存。
    public static let empty = Archive(feeds: [], translations: [:])

    /// URL のフィードの保存。
    public func snapshot(for url: String) -> FeedSnapshot? {
        feeds.first { $0.url == url }
    }

    /// 公開から 7 日より古い記事を捨て（公開時刻の無い記事は残す）、残った記事の無い訳も捨てたもの。
    public func pruned(at now: Timestamp) -> Archive {
        let oldest = now.adding(seconds: -Self.retentionDays * 86_400)
        let feeds = self.feeds.map { feed in
            FeedSnapshot(
                url: feed.url, validators: feed.validators,
                articles: feed.articles.filter { ($0.published ?? now) >= oldest })
        }
        let kept = Set(feeds.flatMap { $0.articles.map(\.identifier) })
        let translations = self.translations.mapValues { $0.filter { kept.contains($0.key) } }.filter {
            !$0.value.isEmpty
        }
        return Archive(feeds: feeds, translations: translations)
    }
}
