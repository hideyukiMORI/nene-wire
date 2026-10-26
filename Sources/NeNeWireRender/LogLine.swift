/// 起動直後の接続シーケンスの 1 行（FR-20・ADR 0009）。`at` は起動してからのミリ秒で、そこから打ち出される。
public struct LogLine: Sendable, Hashable {
    public let text: String
    public let at: Int

    /// 行を作る。
    public init(text: String, at: Int) {
        self.text = text
        self.at = at
    }
}
