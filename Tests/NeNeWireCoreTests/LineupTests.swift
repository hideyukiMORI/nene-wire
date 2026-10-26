import Testing

@testable import NeNeWireCore

/// 表示の並べ方（FR-12）。
struct LineupTests {
    private func article(_ id: String, feed: String, at seconds: Int64?) -> Article? {
        let item = FeedItem(
            title: id, link: "https://example.com/\(id)", summary: "", published: seconds.map(Timestamp.since1970),
            identifier: id)
        return FeedURL.parse("https://example.com/feed").flatMap { url in
            Feed.make(name: feed, url: url, enabled: true).flatMap { Article.from(item, feed: $0) }
        }
    }

    @Test func feedsTakeTurnsAndEachFeedGoesNewestFirst() {
        let first = [
            article("a-old", feed: "A", at: 10), article("a-new", feed: "A", at: 30),
            article("a-none", feed: "A", at: nil),
        ]
        let second = [article("b-new", feed: "B", at: 20)]
        let order = Lineup.interleaved([first.compactMap { $0 }, second.compactMap { $0 }]).map(\.identifier)
        #expect(order == ["a-new", "b-new", "a-old", "a-none"])
    }

    @Test func duplicatesAcrossFeedsAppearOnce() {
        let shared = [article("same", feed: "A", at: 5), article("same", feed: "B", at: 5)].compactMap { $0 }
        #expect(Lineup.interleaved([[shared[0]], [shared[1]]]).count == 1)
        #expect(Lineup.interleaved([]).isEmpty)
    }
}
