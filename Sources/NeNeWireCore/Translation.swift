/// 見出しと出だしの訳（FR-10）。
public struct Translation: Sendable, Hashable {
    public let headline: String
    public let lede: String?

    /// 訳を作る。
    public init(headline: String, lede: String?) {
        self.headline = headline
        self.lede = lede
    }
}
