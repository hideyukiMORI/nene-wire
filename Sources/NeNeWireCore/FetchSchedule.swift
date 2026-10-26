/// いつどのフィードを取りに行くか（FR-07・ADR 0007）。礼儀正しく取る規則の正本。
///
/// 1 度に取るのは 1 本だけ。どのフィードも、取れたら 15 分あけ、失敗したら 2・4・8… 分（最大 60 分）あけて取り直す。
public struct FetchSchedule: Sendable, Hashable {
    /// 取れたあと、次に取りに行くまでの秒数（15 分）。
    public static let interval: Int64 = 15 * 60
    /// 失敗が続いたときに空ける秒数の上限（60 分）。
    public static let longestBackoff: Int64 = 60 * 60

    public let statuses: [FeedStatus]

    private init(statuses: [FeedStatus]) {
        self.statuses = statuses
    }

    /// 起動したとき。どのフィードもすぐに取りに行ってよい。
    public static func starting(feeds count: Int, at now: Timestamp) -> FetchSchedule {
        FetchSchedule(statuses: Array(repeating: .pending(at: now), count: count))
    }

    /// `failures` 回続けて失敗したあとに空ける秒数（2 分から倍々・最大 60 分）。
    public static func backoff(failures: Int) -> Int64 {
        let minutes = Int64(1) << Int64(min(max(failures, 1), 6))
        return min(minutes * 60, longestBackoff)
    }

    /// いま取りに行くフィード（予定の時刻を過ぎたもののうち、いちばん早いもの・同じならフィードの順）。無ければ nil。
    public func due(at now: Timestamp) -> Int? {
        statuses.indices.filter { statuses[$0].nextDue <= now }.min { statuses[$0].nextDue < statuses[$1].nextDue }
    }

    /// 次に取りに行く予定の時刻（いちばん早いもの）。
    public var nextDue: Timestamp? {
        statuses.map(\.nextDue).min()
    }

    /// `feed` 番目の取得の結果を記録した次の予定。`articles` は使える記事の件数。
    public func recording(_ outcome: FetchOutcome, feed: Int, articles: Int, at now: Timestamp) -> FetchSchedule {
        guard statuses.indices.contains(feed) else {
            return self
        }
        var next = statuses
        next[feed] = .after(outcome, articles: articles, previous: statuses[feed], now: now)
        return FetchSchedule(statuses: next)
    }
}
