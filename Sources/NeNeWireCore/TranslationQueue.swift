/// 翻訳待ちと訳の控え（FR-10・FR-13・ADR 0010）。訳した記事は訳し直さない。失敗した記事は 10 分あけて取り直す。
/// 控えはいま巡りにある記事の分だけを残す（一晩流しても増え続けない・FR-02）。
public struct TranslationQueue: Sendable, Hashable {
    /// 1 回に訳す記事の上限。
    public static let batch = 8
    /// 失敗したあとに空ける秒数。
    public static let retry: Int64 = 10 * 60

    /// 表示の言語。
    public let target: String
    private var waiting: [TranslationJob] = []
    private var done: [String: Translation] = [:]

    private init(target: String) {
        self.target = target
    }

    /// 空の待ち行列。
    public static func empty(target: String) -> TranslationQueue {
        TranslationQueue(target: target)
    }

    /// 訳を待っている件数。
    public var pending: Int {
        waiting.count
    }

    /// 訳の控えのすべて（保存するため・ADR 0014）。
    public var translations: [String: Translation] {
        done
    }

    /// 保存した訳の控えを読み戻す（待っている記事からは外す）。
    public mutating func remember(_ saved: [String: Translation]) {
        done.merge(saved) { current, _ in current }
        waiting.removeAll { done[$0.identifier] != nil }
    }

    /// 訳してあればその訳。
    public func translation(for identifier: String) -> Translation? {
        done[identifier]
    }

    /// 表示の言語と違う記事を待ち行列に足す（訳してあるもの・待っているもの・言語が分からないものは足さない）。先に来たものから訳す。
    public mutating func enqueue(_ articles: [Article]) {
        for article in articles where done[article.identifier] == nil {
            guard !waiting.contains(where: { $0.identifier == article.identifier }),
                let source = LanguageGuess.of(article.headline + " " + (article.lede ?? "")), source != target
            else {
                continue
            }
            waiting.append(
                TranslationJob(
                    identifier: article.identifier, headline: article.headline, lede: article.lede, source: source,
                    retryAt: nil))
        }
    }

    /// いま訳してよい記事（同じ言語のものだけを、上限まで）。
    public func nextBatch(at now: Timestamp) -> [TranslationJob] {
        let due = waiting.filter { ($0.retryAt ?? now) <= now }
        guard let first = due.first else {
            return []
        }
        return Array(due.filter { $0.source == first.source }.prefix(Self.batch))
    }

    /// 訳を受け取る。`texts` は `jobs` の `texts` を順につなげたものの訳。
    public mutating func record(_ jobs: [TranslationJob], texts: [String]) {
        var cursor = 0
        for job in jobs {
            let count = job.texts.count
            guard cursor + count <= texts.count else {
                return
            }
            let lede = count > 1 ? texts[cursor + 1] : nil
            done[job.identifier] = Translation(headline: texts[cursor], lede: lede)
            waiting.removeAll { $0.identifier == job.identifier }
            cursor += count
        }
    }

    /// 訳せなかった。10 分あけて取り直す。
    public mutating func fail(_ jobs: [TranslationJob], at now: Timestamp) {
        let ids = Set(jobs.map(\.identifier))
        waiting = waiting.map { job in
            guard ids.contains(job.identifier) else {
                return job
            }
            return TranslationJob(
                identifier: job.identifier, headline: job.headline, lede: job.lede, source: job.source,
                retryAt: now.adding(seconds: Self.retry))
        }
    }

    /// いま巡りにある記事の分だけを残す。
    public mutating func keep(only identifiers: Set<String>) {
        done = done.filter { identifiers.contains($0.key) }
        waiting.removeAll { !identifiers.contains($0.identifier) }
    }
}
