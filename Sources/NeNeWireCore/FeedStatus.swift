/// 1 本のフィードの取得の記録（FR-07）。
public struct FeedStatus: Sendable, Hashable {
    public let health: FeedHealth
    /// 次に取りに行ってよい時刻。
    public let nextDue: Timestamp
    /// 続けて失敗した回数（成功で 0 に戻る）。
    public let failures: Int
    /// 次の条件付きの取得の手がかり。
    public let validators: Validators

    private init(health: FeedHealth, nextDue: Timestamp, failures: Int, validators: Validators) {
        self.health = health
        self.nextDue = nextDue
        self.failures = failures
        self.validators = validators
    }

    /// まだ取っていないフィード（すぐに取りに行ってよい）。
    static func pending(at now: Timestamp) -> FeedStatus {
        FeedStatus(health: .pending, nextDue: now, failures: 0, validators: .none)
    }

    /// 保存した記事と手がかりから再開するフィード（すぐに条件付きで取りに行ってよい・ADR 0014）。
    static func resumed(articles count: Int, validators: Validators, at now: Timestamp) -> FeedStatus {
        FeedStatus(
            health: count > 0 ? .unchanged(count: count) : .pending, nextDue: now, failures: 0, validators: validators)
    }

    /// 取得の結果を記録した次の状態。
    static func after(
        _ outcome: FetchOutcome, articles count: Int, previous: FeedStatus, now: Timestamp
    ) -> FeedStatus {
        switch outcome {
        case .fetched(_, let headers):
            return FeedStatus(
                health: .fetched(count: count), nextDue: now.adding(seconds: FetchSchedule.interval), failures: 0,
                validators: Validators.from(headers))
        case .notModified:
            return FeedStatus(
                health: .unchanged(count: count), nextDue: now.adding(seconds: FetchSchedule.interval), failures: 0,
                validators: previous.validators)
        case .failed(let failure):
            let failures = previous.failures + 1
            return FeedStatus(
                health: .failed(failure), nextDue: now.adding(seconds: FetchSchedule.backoff(failures: failures)),
                failures: failures, validators: previous.validators)
        }
    }
}
