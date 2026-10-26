import Testing

@testable import NeNeWireCore

/// 言語の判定・翻訳の出力の読み方・翻訳待ちと訳の控え（FR-09・FR-10・ADR 0010）。
struct TranslationTests {
    private let now = Timestamp.since1970(1_000_000)

    private func article(_ id: String, _ headline: String, lede: String = "") -> Article? {
        let item = FeedItem(
            title: headline, link: "https://example.com/\(id)", summary: lede, published: nil, identifier: id)
        return FeedURL.parse("https://example.com/feed").flatMap { url in
            Feed.make(name: "F", url: url, enabled: true).flatMap { Article.from(item, feed: $0) }
        }
    }

    @Test func languageIsGuessedFromTheKindsOfLetters() {
        #expect(LanguageGuess.of("北海の洋上風力、送電網の遅れ") == "ja")
        #expect(LanguageGuess.of("NHK ニュース 7 件") == "ja")
        #expect(LanguageGuess.of("Night trains return to the coastal line") == "en")
        #expect(LanguageGuess.of("Lula défait Bolsonaro") == "en")
        #expect(LanguageGuess.of("Привет мир") == nil)
        #expect(LanguageGuess.of("2026 / 10 / 26") == nil)
    }

    @Test func replyLinesAreReadInOrderAndProblemsAreNamed() {
        let ok = Array("1\t二つ目\n0\t一つ目\n".utf8)
        #expect(TranslationReply.interpret(exitCode: 0, output: ok, count: 2) == .translated(["一つ目", "二つ目"]))
        #expect(
            TranslationReply.interpret(exitCode: 3, output: Array("ERR\timport\n".utf8), count: 1)
                == .unavailable(.notInstalled))
        #expect(
            TranslationReply.interpret(exitCode: 4, output: Array("ERR\tmodel\n".utf8), count: 1)
                == .unavailable(.missingModel))
        #expect(
            TranslationReply.interpret(exitCode: 0, output: Array("0\tだけ\n".utf8), count: 2)
                == .unavailable(.crashed(0)))
        #expect(TranslationReply.interpret(exitCode: nil, output: [], count: 1) == .unavailable(.crashed(nil)))
    }

    @Test func onlyForeignArticlesWaitAndEachWaitsOnce() throws {
        var queue = TranslationQueue.empty(target: "ja")
        let english = try #require(article("e1", "Night trains return", lede: "Overnight services resume."))
        let japanese = try #require(article("j1", "夜行列車が戻る"))
        queue.enqueue([english, japanese, english])
        #expect(queue.pending == 1)
        let batch = queue.nextBatch(at: now)
        #expect(batch.map(\.identifier) == ["e1"])
        #expect(batch.first?.texts == ["Night trains return", "Overnight services resume."])
        queue.record(batch, texts: ["夜行列車が戻る", "夜行便が再開する。"])
        #expect(queue.pending == 0)
        #expect(queue.translation(for: "e1") == Translation(headline: "夜行列車が戻る", lede: "夜行便が再開する。"))
        queue.enqueue([english])
        #expect(queue.pending == 0)
    }

    @Test func batchesAreCappedAndFailuresWaitTenMinutes() throws {
        var queue = TranslationQueue.empty(target: "ja")
        let articles = try (0..<20).map { try #require(article("a\($0)", "Headline number \($0)")) }
        queue.enqueue(articles)
        let batch = queue.nextBatch(at: now)
        #expect(batch.count == TranslationQueue.batch)
        queue.fail(batch, at: now)
        #expect(queue.nextBatch(at: now).map(\.identifier) == (8..<16).map { "a\($0)" })
        #expect(queue.nextBatch(at: now.adding(seconds: TranslationQueue.retry)).first?.identifier == "a0")
        queue.keep(only: ["a19"])
        #expect(queue.pending == 1)
    }

    @Test func aTranslatedArticleKeepsItsOriginalHeadline() throws {
        let english = try #require(article("e1", "Night trains return", lede: "Overnight services resume."))
        let shown = english.translated(Translation(headline: "夜行列車が戻る", lede: nil))
        #expect(shown.headline == "夜行列車が戻る")
        #expect(shown.originalHeadline == "Night trains return")
        #expect(shown.lede == "Overnight services resume.")
        #expect(shown.identifier == "e1")
    }
}
