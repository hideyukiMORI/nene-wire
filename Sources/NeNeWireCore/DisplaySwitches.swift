/// 表示の設定のうち、オン／オフで切り替えるもの。
public struct DisplaySwitches: Sendable, Hashable {
    /// 文字の雨（FR-18）。
    public let rain: Bool
    /// 訳したときに原文の見出しを添えるか（FR-14）。
    public let original: Bool
    /// 表示の言語と違う記事を訳すか（施主の依頼・ADR 0013）。
    public let translate: Bool

    /// 組を作る。
    public init(rain: Bool, original: Bool, translate: Bool) {
        self.rain = rain
        self.original = original
        self.translate = translate
    }

    /// 既定（どれもオン）。
    public static let defaults = DisplaySwitches(rain: true, original: true, translate: true)
}
