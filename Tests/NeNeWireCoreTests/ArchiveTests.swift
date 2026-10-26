import Testing

@testable import NeNeWireCore

/// 記事と訳の保存（FR-11・ADR 0014）。
struct ArchiveTests {
    private let now = Timestamp.since1970(2_000_000_000)

    private func article(_ id: String, _ headline: String, lede: String? = nil, age days: Int64? = 0) -> Article? {
        Article.restored(
            ArticleFields(
                feedName: "NEON\tTIMES", headline: headline, lede: lede, link: "https://example.com/\(id)",
                published: days.map { now.adding(seconds: -$0 * 86_400) }, identifier: id))
    }

    private func sample() throws -> Archive {
        let feed = FeedSnapshot(
            url: "https://example.com/feed", validators: .make(entityTag: "W/\"a\\b\"", lastModified: nil),
            articles: try [
                #require(article("a1", "改行\nと\tタブと\\を含む見出し", lede: "出だし")),
                #require(article("a2", "時刻の無い記事", age: nil)),
            ])
        return Archive(feeds: [feed], translations: ["ja": ["a1": Translation(headline: "訳", lede: nil)]])
    }

    @Test func anArchiveSurvivesARoundTripIncludingTabsAndNewlines() throws {
        let archive = try sample()
        let text = ArchiveCodec.encode(archive)
        #expect(text.split(separator: "\n").count == 5)
        #expect(ArchiveCodec.decode(text) == .parsed(archive))
    }

    @Test func unreadableArchivesAreNamed() {
        #expect(ArchiveCodec.decode("hello") == .rejected(.notArchive))
        #expect(ArchiveCodec.decode("nene-wire-archive 2\n") == .rejected(.unknownVersion("2")))
        #expect(ArchiveCodec.decode("nene-wire-archive 1\nwhat ever\n") == .rejected(.malformed(line: 2)))
        let orphan = "nene-wire-archive 1\narticle https://x\tid\t\th\t\thttps://x/1\tF\n"
        #expect(ArchiveCodec.decode(orphan) == .rejected(.malformed(line: 2)))
        let badTime = "nene-wire-archive 1\nfeed https://x\t\t\narticle https://x\tid\t=soon\th\t\thttps://x/1\tF\n"
        #expect(ArchiveCodec.decode(badTime) == .rejected(.malformed(line: 3)))
    }

    @Test func articlesOlderThanAWeekAndTheirTranslationsAreDropped() throws {
        let old = try #require(article("old", "古い", age: 8))
        let fresh = try #require(article("new", "新しい", age: 6))
        let undated = try #require(article("undated", "時刻なし", age: nil))
        let archive = Archive(
            feeds: [FeedSnapshot(url: "u", validators: .none, articles: [old, fresh, undated])],
            translations: [
                "ja": ["old": Translation(headline: "x", lede: nil), "new": Translation(headline: "y", lede: nil)]
            ])
        let pruned = archive.pruned(at: now)
        #expect(pruned.feeds[0].articles.map(\.identifier) == ["new", "undated"])
        #expect(pruned.translations["ja"]?.keys.sorted() == ["new"])
    }

    @Test func savedFeedsResumeConditionallyAndAtOnce() {
        let schedule = FetchSchedule.resuming(
            [(articles: 7, validators: .make(entityTag: "e", lastModified: nil)), (articles: 0, validators: .none)],
            at: now)
        #expect(schedule.statuses[0].health == .unchanged(count: 7))
        #expect(schedule.statuses[0].validators.entityTag == "e")
        #expect(schedule.statuses[1].health == .pending)
        #expect(schedule.due(at: now) == 0)
    }

    @Test func restoredArticlesDoNotComeBackAsBreakingNews() throws {
        var rotation = Rotation.empty(feeds: 1)
        rotation.restore(feed: 0, with: [try #require(article("a1", "前に見た"))])
        #expect(rotation.current?.identifier == "a1")
        rotation.replace(feed: 0, with: [try #require(article("a1", "前に見た")), try #require(article("a2", "その後に出た"))])
        #expect(rotation.pendingFresh == 0)
        #expect(rotation.count == 2)
    }

    @Test func rememberedTranslationsAreNotTranslatedAgain() throws {
        var queue = TranslationQueue.empty(target: "ja")
        let english = try #require(article("e1", "Night trains return"))
        queue.enqueue([english])
        #expect(queue.pending == 1)
        queue.remember(["e1": Translation(headline: "夜行列車が戻る", lede: nil)])
        #expect(queue.pending == 0)
        #expect(queue.translations["e1"]?.headline == "夜行列車が戻る")
        queue.enqueue([english])
        #expect(queue.pending == 0)
    }
}
