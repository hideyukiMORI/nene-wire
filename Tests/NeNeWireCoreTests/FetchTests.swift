import Testing

@testable import NeNeWireCore

/// 日付・URL・curl の応答・取得の結果の読み替え（ADR 0005）。
struct FetchTests {
    @Test func datesInBothFormats() {
        #expect(DateText.parse("Mon, 26 Oct 2026 01:07:05 GMT")?.iso8601 == "2026-10-26T01:07:05Z")
        #expect(DateText.parse("Sat, 08 Aug 2026 21:54:30 +0900")?.iso8601 == "2026-08-08T12:54:30Z")
        #expect(DateText.parse("Sun, 25 Oct 2026 20:35:00 -0400")?.iso8601 == "2026-10-26T00:35:00Z")
        #expect(DateText.parse("2026-10-26T10:03:19+09:00")?.iso8601 == "2026-10-26T01:03:19Z")
        #expect(DateText.parse("2026-02-28")?.iso8601 == "2026-02-28T00:00:00Z")
        #expect(DateText.parse("1970-01-01T00:00:00Z")?.seconds == 0)
        #expect(DateText.parse("yesterday") == nil)
        #expect(DateText.parse("2026-13-01T00:00:00Z") == nil)
    }

    @Test func feedURLsNeedHttpAndAHost() {
        #expect(FeedURL.parse(" https://Example.COM:8443/rss?x=1 ")?.host == "example.com")
        #expect(FeedURL.parse("http://user@example.org/feed")?.host == "example.org")
        #expect(FeedURL.parse("ftp://example.com/feed") == nil)
        #expect(FeedURL.parse("https:///feed") == nil)
        #expect(FeedURL.parse("https://exa mple.com/") == nil)
    }

    @Test func defaultFeedsAreFourHttpsFeeds() {
        #expect(Feed.defaults.count == 4)
        #expect(Feed.defaults.allSatisfy { $0.enabled && $0.url.text.hasPrefix("https://") })
    }

    @Test func responseReadsTheLastHeaderBlockAfterRedirects() throws {
        let raw =
            "HTTP/2 301\r\nlocation: https://b/\r\n\r\nHTTP/1.1 200 OK\r\nETag: W/\"x\"\r\nContent-Type: text/xml\r\n\r\n<rss/>"
        guard case .parsed(let response) = HTTPResponse.parse(Array(raw.utf8)) else {
            Issue.record("読めない")
            return
        }
        #expect(response.status == 200)
        #expect(response.header("etag") == "W/\"x\"")
        #expect(String(decoding: response.body, as: UTF8.self) == "<rss/>")
        #expect(HTTPResponse.parse(Array("<rss/>".utf8)) == .rejected(.noStatusLine))
    }

    @Test func interpreterMapsCurlResults() {
        let feed = "HTTP/2 200\r\n\r\n" + FeedParserTests.rss1
        guard
            case .fetched(let document, _) = FetchInterpreter.interpret(
                exitCode: 0, output: Array(feed.utf8), errorOutput: [])
        else {
            Issue.record("取れていない")
            return
        }
        #expect(document.items.count == 1)
        let notModified = FetchInterpreter.interpret(
            exitCode: 0, output: Array("HTTP/1.1 304 Not Modified\r\n\r\n".utf8), errorOutput: [])
        #expect(notModified == .notModified)
        let missing = FetchInterpreter.interpret(
            exitCode: 0, output: Array("HTTP/2 404\r\n\r\nnope".utf8), errorOutput: [])
        #expect(missing == .failed(.status(404)))
        let offline = FetchInterpreter.interpret(
            exitCode: 6, output: [], errorOutput: Array("curl: (6) Could not resolve host: x\nmore".utf8))
        #expect(offline == .failed(.transport(code: 6, message: "curl: (6) Could not resolve host: x")))
        let page = FetchInterpreter.interpret(
            exitCode: 0, output: Array("HTTP/2 200\r\n\r\n<html></html>".utf8), errorOutput: [])
        #expect(page == .failed(.notFeed(.notFeed)))
    }
}
