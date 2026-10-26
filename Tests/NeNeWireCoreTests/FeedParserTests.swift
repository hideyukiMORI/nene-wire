import Testing

@testable import NeNeWireCore

/// RSS 2.0・RSS 1.0・Atom の解析（FR-07・FR-08・ADR 0005）。XML は手で作ったもので、実際の記事は使わない（Q6）。
struct FeedParserTests {
    static let rss2 = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:content="http://purl.org/rss/1.0/modules/content/">
          <channel>
            <title>Example &amp; Co</title>
            <item>
              <title><![CDATA[First <b>headline</b>]]></title>
              <link>https://example.com/a?x=1&amp;y=2</link>
              <description>&lt;p&gt;One. Two.&lt;/p&gt;</description>
              <pubDate>Mon, 26 Oct 2026 01:07:05 GMT</pubDate>
              <guid isPermaLink="false">id-1</guid>
              <media:title>Not the headline</media:title>
            </item>
            <item>
              <title>Second</title>
              <link>https://example.com/b</link>
              <description></description>
              <content:encoded><![CDATA[<p>From content.</p>]]></content:encoded>
            </item>
          </channel>
        </rss>
        """

    static let rss1 = """
        <?xml version="1.0" encoding="utf-8"?>
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <channel rdf:about="https://example.jp/"><title>例のニュース</title></channel>
          <item rdf:about="https://example.jp/1">
            <title>見出しです</title>
            <link>https://example.jp/1</link>
            <description>最初の文です。次の文です。</description>
            <dc:date>2026-10-26T10:03:19+09:00</dc:date>
          </item>
        </rdf:RDF>
        """

    static let atom = """
        <?xml version="1.0"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title type="text">Atom example</title>
          <link rel="self" href="https://example.org/feed"/>
          <entry>
            <title>Entry title</title>
            <link rel="related" href="https://example.org/related"/>
            <link href="https://example.org/entry"/>
            <id>urn:entry:1</id>
            <updated>2026-10-25T00:00:00Z</updated>
            <published>2026-10-24T12:30:00.123-04:00</published>
            <summary type="html">&lt;p&gt;Summary text.&lt;/p&gt;</summary>
          </entry>
        </feed>
        """

    static func document(_ text: String) throws -> FeedDocument {
        guard case .parsed(let document) = FeedParser.parse(text) else {
            Issue.record("解析できない")
            return try #require(nil as FeedDocument?)
        }
        return document
    }

    @Test func readsRss2() throws {
        let document = try Self.document(Self.rss2)
        #expect(document.format == .rss2)
        #expect(document.title == "Example & Co")
        #expect(document.items.count == 2)
        let first = document.items[0]
        #expect(first.title == "First <b>headline</b>")
        #expect(first.link == "https://example.com/a?x=1&y=2")
        #expect(first.summary == "<p>One. Two.</p>")
        #expect(first.identifier == "id-1")
        #expect(first.published == DateText.parse("2026-10-26T01:07:05Z"))
        #expect(document.items[1].summary == "<p>From content.</p>")
        #expect(document.items[1].identifier == "https://example.com/b")
    }

    @Test func readsRss1() throws {
        let document = try Self.document(Self.rss1)
        #expect(document.format == .rss1)
        #expect(document.title == "例のニュース")
        #expect(document.items.map(\.title) == ["見出しです"])
        #expect(document.items[0].published?.iso8601 == "2026-10-26T01:03:19Z")
    }

    @Test func readsAtomWithTheAlternateLinkAndThePublishedDate() throws {
        let document = try Self.document(Self.atom)
        #expect(document.format == .atom)
        #expect(document.title == "Atom example")
        let entry = try #require(document.items.first)
        #expect(entry.link == "https://example.org/entry")
        #expect(entry.identifier == "urn:entry:1")
        #expect(entry.published?.iso8601 == "2026-10-24T16:30:00Z")
    }

    @Test func rejectsHTMLAndOtherEncodings() {
        #expect(FeedParser.parse("<!DOCTYPE html><html><body>no</body></html>") == .rejected(.notFeed))
        #expect(FeedParser.parse("") == .rejected(.notFeed))
        let sjis = "<?xml version=\"1.0\" encoding=\"Shift_JIS\"?><rss></rss>"
        #expect(FeedParser.parse(sjis) == .rejected(.unsupportedEncoding("Shift_JIS")))
    }

    @Test func articleCleansTheHeadlineAndMakesALede() throws {
        let document = try Self.document(Self.rss2)
        let feed = try #require(Feed.defaults.first)
        let article = try #require(Article.from(document.items[0], feed: feed))
        #expect(article.headline == "First headline")
        #expect(article.lede == "One. Two.")
        #expect(article.feedName == feed.name)
    }
}
