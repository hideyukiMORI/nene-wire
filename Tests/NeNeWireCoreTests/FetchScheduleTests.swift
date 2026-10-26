import Testing

@testable import NeNeWireCore

/// 取得の予定と表示の巡り（FR-07・FR-12・ADR 0007）。
struct FetchScheduleTests {
    private let start = Timestamp.since1970(1_000_000)

    private func article(_ id: String, at seconds: Int64) -> Article? {
        let item = FeedItem(
            title: id, link: "https://example.com/\(id)", summary: "", published: .since1970(seconds), identifier: id)
        return FeedURL.parse("https://example.com/feed").flatMap { url in
            Feed.make(name: "F", url: url, enabled: true).flatMap { Article.from(item, feed: $0) }
        }
    }

    private func document() -> FetchOutcome {
        let xml = "<rss version=\"2.0\"><channel><title>t</title></channel></rss>"
        guard case .parsed(let parsed) = FeedParser.parse(xml) else {
            return .notModified
        }
        return .fetched(parsed, headers: [HTTPHeader(name: "etag", value: "\"v1\"")])
    }

    @Test func everyFeedIsDueAtStartAndOneIsTakenAtATimeInOrder() {
        let schedule = FetchSchedule.starting(feeds: 3, at: start)
        #expect(schedule.due(at: start) == 0)
        let next = schedule.recording(document(), feed: 0, articles: 5, at: start)
        #expect(next.due(at: start) == 1)
        #expect(next.statuses[0].health == .fetched(count: 5))
        #expect(next.statuses[0].validators.entityTag == "\"v1\"")
    }

    @Test func successWaitsFifteenMinutesAndNotModifiedKeepsValidators() {
        var schedule = FetchSchedule.starting(feeds: 1, at: start).recording(
            document(), feed: 0, articles: 5, at: start)
        #expect(schedule.due(at: start.adding(seconds: 15 * 60 - 1)) == nil)
        #expect(schedule.due(at: start.adding(seconds: 15 * 60)) == 0)
        schedule = schedule.recording(.notModified, feed: 0, articles: 5, at: start.adding(seconds: 900))
        #expect(schedule.statuses[0].health == .unchanged(count: 5))
        #expect(schedule.statuses[0].validators.entityTag == "\"v1\"")
        #expect(schedule.nextDue == start.adding(seconds: 1800))
    }

    @Test func failuresBackOffAndCapAtAnHour() {
        #expect([1, 2, 3, 4, 5, 6, 9].map(FetchSchedule.backoff) == [120, 240, 480, 960, 1920, 3600, 3600])
        var schedule = FetchSchedule.starting(feeds: 1, at: start)
        schedule = schedule.recording(.failed(.status(503)), feed: 0, articles: 0, at: start)
        schedule = schedule.recording(.failed(.status(503)), feed: 0, articles: 0, at: start)
        #expect(schedule.statuses[0].failures == 2)
        #expect(schedule.nextDue == start.adding(seconds: 240))
        schedule = schedule.recording(document(), feed: 0, articles: 1, at: start)
        #expect(schedule.statuses[0].failures == 0)
    }

    @Test func rotationShowsTheFirstArrivalAtOnceAndInterruptsWithNewArticles() {
        var rotation = Rotation.empty(feeds: 2)
        #expect(rotation.current == nil)
        rotation.replace(feed: 0, with: [article("a1", at: 10), article("a2", at: 20)].compactMap { $0 })
        #expect(rotation.current?.identifier == "a2")
        #expect(!rotation.isFresh)
        rotation.replace(
            feed: 0, with: [article("a1", at: 10), article("a2", at: 20), article("a3", at: 30)].compactMap { $0 })
        #expect(rotation.pendingFresh == 1)
        rotation.advance()
        #expect(rotation.current?.identifier == "a3")
        #expect(rotation.isFresh)
        rotation.advance()
        #expect(rotation.current?.identifier == "a1")
        rotation.advance()
        #expect(rotation.current?.identifier == "a3")
        #expect(rotation.count == 3)
        rotation.goBack()
        #expect(rotation.current?.identifier == "a1")
    }

    @Test func aFeedsFirstFetchJoinsTheCurrentCycleInsteadOfBreakingNews() {
        var rotation = Rotation.empty(feeds: 2)
        rotation.replace(feed: 0, with: [article("a1", at: 10), article("a2", at: 20)].compactMap { $0 })
        rotation.replace(feed: 1, with: [article("b1", at: 10), article("b2", at: 20)].compactMap { $0 })
        #expect(rotation.pendingFresh == 0)
        #expect(rotation.count == 4)
        var seen = [rotation.current?.identifier]
        for _ in 0..<3 {
            rotation.advance()
            seen.append(rotation.current?.identifier)
        }
        #expect(seen == ["a2", "b2", "a1", "b1"])
    }

    @Test func validatorsIgnoreEmptyValues() {
        let validators = Validators.from([
            HTTPHeader(name: "etag", value: ""), HTTPHeader(name: "last-modified", value: "x"),
        ])
        #expect(validators.entityTag == nil)
        #expect(validators.lastModified == "x")
    }
}
