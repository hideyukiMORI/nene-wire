/// 翻訳を待っている 1 件の記事（FR-10）。
public struct TranslationJob: Sendable, Hashable {
    public let identifier: String
    public let headline: String
    public let lede: String?
    /// 言語のコード（訳す前）。
    public let source: String
    /// 失敗したとき、次に試してよい時刻。
    let retryAt: Timestamp?

    init(identifier: String, headline: String, lede: String?, source: String, retryAt: Timestamp?) {
        self.identifier = identifier
        self.headline = headline
        self.lede = lede
        self.source = source
        self.retryAt = retryAt
    }

    /// 翻訳の手段に渡す文字列（見出しと、あれば出だし）。
    public var texts: [String] {
        [headline] + (lede.map { [$0] } ?? [])
    }
}
