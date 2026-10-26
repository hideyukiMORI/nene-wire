import NeNeWireCore

/// `--list` の一覧（Phase 3 の手順 1・ADR 0005）。フィードを 1 本ずつ取り、見出し・出だし・リンク・公開時刻を素のまま並べる。
/// 取れなかったフィードは理由を 1 行出して続ける。
enum Listing {
    static func lines(for feeds: [Feed], environment: [String]) -> [String] {
        feeds.flatMap { feed in lines(for: feed, outcome: FeedFetch.outcome(feed, environment: environment)) + [""] }
    }

    private static func lines(for feed: Feed, outcome: FetchOutcome) -> [String] {
        switch outcome {
        case .notModified:
            return ["== \(feed.name) (\(feed.url.host)): 更新なし"]
        case .failed(let failure):
            return ["!! \(feed.name) (\(feed.url.host)): \(FeedFetch.describe(failure))"]
        case .fetched(let document, _):
            let articles = document.items.compactMap { Article.from($0, feed: feed) }
            let header = "== \(feed.name) (\(feed.url.host)) \(document.format) \(articles.count) 件"
            return [header] + articles.flatMap(describe)
        }
    }

    private static func describe(_ article: Article) -> [String] {
        var lines = ["- " + article.headline]
        if let lede = article.lede {
            lines.append("  " + lede)
        }
        lines.append("  " + article.link)
        lines.append("  " + (article.published?.iso8601 ?? "（公開時刻なし）"))
        return lines
    }
}
