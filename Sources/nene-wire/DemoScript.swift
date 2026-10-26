import NeNeWireCore

/// `--demo` の筋書き（ADR 0008）。ネットを使わず、架空のフィードと記事で帯を動かす（画面写真と、ネットの無い所での試し用）。
/// 記事はすべてデザイン用の架空の文面で、実在の媒体の名前は使わない（Q6: 実際の記事をリポジトリに入れない）。
/// 起動直後に 4 本が順に「取れ」、20 秒後に 1 本目のフィードへ新しい記事が 1 件届く（速報の割り込みを見せる）。
struct DemoScript {
    /// 架空の記事 1 件。
    private struct Item {
        let headline: String
        let lede: String
        let published: String
        let slug: String
    }

    /// 速報が届くまでの秒数。
    static let breakingDelay: Int64 = 20

    let feeds: [Feed]
    private let documents: [FeedDocument]
    private let breaking: FeedDocument?

    init() {
        let pairs = Self.sources.compactMap { name, xml -> (Feed, FeedDocument)? in
            guard
                let url = FeedURL.parse(
                    "https://example.com/demo/\(name.lowercased().split(separator: " ").joined(separator: "-"))"),
                let feed = Feed.make(name: name, url: url, enabled: true),
                case .parsed(let document) = FeedParser.parse(xml)
            else {
                return nil
            }
            return (feed, document)
        }
        feeds = pairs.map(\.0)
        documents = pairs.map(\.1)
        if case .parsed(let document) = FeedParser.parse(Self.breakingXML) {
            breaking = document
        } else {
            breaking = nil
        }
    }

    /// `feed` 番目のフィードを取った結果。`late` なら速報の 1 件を足した版。
    func outcome(feed: Int, late: Bool) -> FetchOutcome {
        guard documents.indices.contains(feed) else {
            return .failed(.status(404))
        }
        if late, feed == 0, let breaking {
            return .fetched(breaking, headers: [])
        }
        return .fetched(documents[feed], headers: [])
    }

    private static func rss(_ items: [Item]) -> String {
        let body = items.map { item in
            "<item><title>\(item.headline)</title><link>https://example.com/demo/\(item.slug)</link><guid>\(item.slug)</guid>"
                + "<pubDate>\(item.published)</pubDate><description>\(item.lede)</description></item>"
        }.joined()
        return "<rss version=\"2.0\"><channel><title>demo</title>\(body)</channel></rss>"
    }

    private static let firstItems: [Item] = [
        Item(
            headline: "北海の洋上風力、送電網の遅れで全面稼働が半年ずれ込む",
            lede: "英国北部の洋上風力発電所で、陸上の送電網の整備が追いつかず、全面稼働が来年春までずれ込む見通しとなった。運営会社は、完成済みの風車の一部を止めたまま保守を続けている。",
            published: "Mon, 26 Oct 2026 03:31:00 GMT", slug: "neon-0001"
        ),
        Item(
            headline: "深夜の自動運転バス、湾岸の 3 路線で試験運行を延長",
            lede: "湾岸地区で続けている深夜の自動運転バスの試験運行について、運行会社は利用者が想定を上回ったとして、期間を来年 3 月まで延ばすと発表した。",
            published: "Mon, 26 Oct 2026 02:10:00 GMT", slug: "neon-0002"
        ),
    ]

    private static let sources: [(String, String)] = [
        ("NEON TIMES", rss(firstItems)),
        (
            "GRID DAILY",
            rss([
                Item(
                    headline: "City grid rolls out street-level batteries to ride out heat waves",
                    lede:
                        "The city's utility says a network of small batteries installed under bus shelters cut evening demand peaks by nearly a tenth during the last heat wave. Expansion to the outer wards starts next spring.",
                    published: "Mon, 26 Oct 2026 04:05:00 GMT", slug: "grid-0001"
                ),
                Item(
                    headline: "Night trains return to the coastal line after a decade",
                    lede:
                        "Overnight services between the port and the capital will resume in December, operators said, citing demand from travellers avoiding short-haul flights.",
                    published: "Mon, 26 Oct 2026 01:45:00 GMT", slug: "grid-0002"
                ),
            ])
        ),
        (
            "PORT WIRE",
            rss([
                Item(
                    headline: "港の荷役ロボット、夜間の自動化率が初めて 8 割を超える",
                    lede: "港湾局によると、夜間のコンテナの積み降ろしのうち、ロボットだけで終えた作業が先月初めて 8 割を超えた。人の作業は点検と異常時の対応に移りつつある。",
                    published: "Mon, 26 Oct 2026 03:02:00 GMT", slug: "port-0001"
                )
            ])
        ),
        (
            "ORBITAL NEWS",
            rss([
                Item(
                    headline: "Small weather satellite beams back its first full-disc images",
                    lede:
                        "A shoebox-sized weather satellite launched last month has returned its first full-disc images of the planet, its operators said. Forecasters hope to fold the data into storm warnings next year.",
                    published: "Mon, 26 Oct 2026 02:55:00 GMT", slug: "orbit-0001"
                )
            ])
        ),
    ]

    private static let breakingXML = rss(
        [
            Item(
                headline: "湾岸エリアで大規模な通信障害、復旧のめど立たず",
                lede: "湾岸エリアの広い範囲で、携帯電話と固定回線がつながりにくくなっている。通信各社は原因を調べている。",
                published: "Mon, 26 Oct 2026 05:20:00 GMT", slug: "neon-0003"
            )
        ] + firstItems)
}
