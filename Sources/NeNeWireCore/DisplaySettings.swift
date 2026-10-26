/// 表示の設定（FR-24）。選べる値は決まった列で、設定画面の ← → でその中を巡る。
public struct DisplaySettings: Sendable, Hashable {
    /// 表示する言語（言語のコード）。
    public static let languages = ["ja", "en", "zh", "ko", "fr", "de", "es"]
    /// 1 件の表示時間（秒）。
    public static let intervals = [6, 8, 10, 12, 15, 20, 30]
    /// 色のテーマの名前。
    public static let themes = ["PHOSPHOR", "AMBER", "CYAN", "MAGENTA"]

    public let language: String
    public let interval: Int
    public let theme: String
    /// 文字の雨（FR-18）。
    public let rain: Bool
    /// 訳したときに原文の見出しを添えるか（FR-14）。
    public let original: Bool

    private init(language: String, interval: Int, theme: String, rain: Bool, original: Bool) {
        self.language = language
        self.interval = interval
        self.theme = theme
        self.rain = rain
        self.original = original
    }

    /// 既定（日本語・12 秒・PHOSPHOR・雨あり・原文あり）。
    public static let defaults = DisplaySettings(
        language: "ja", interval: 12, theme: "PHOSPHOR", rain: true, original: true)

    /// 値から作る。`switches` は文字の雨と原文の見出し。選べる値の外なら nil。
    public static func make(
        language: String, interval: Int, theme: String, switches: (rain: Bool, original: Bool)
    ) -> DisplaySettings? {
        guard languages.contains(language), intervals.contains(interval), themes.contains(theme) else {
            return nil
        }
        return DisplaySettings(
            language: language, interval: interval, theme: theme, rain: switches.rain, original: switches.original)
    }

    /// `option` 番目の項目を、選べる値の列の中で `step` だけ動かしたもの（端では巡る）。
    public func stepping(_ option: DisplayOption, by step: Int) -> DisplaySettings {
        func cycle<Value: Equatable>(_ values: [Value], _ current: Value) -> Value {
            let index = values.firstIndex(of: current) ?? 0
            return values[((index + step) % values.count + values.count) % values.count]
        }
        switch option {
        case .language:
            return DisplaySettings(
                language: cycle(Self.languages, language), interval: interval, theme: theme, rain: rain,
                original: original)
        case .interval:
            return DisplaySettings(
                language: language, interval: cycle(Self.intervals, interval), theme: theme, rain: rain,
                original: original)
        case .theme:
            return DisplaySettings(
                language: language, interval: interval, theme: cycle(Self.themes, theme), rain: rain, original: original
            )
        case .rain:
            return DisplaySettings(
                language: language, interval: interval, theme: theme, rain: !rain, original: original)
        case .original:
            return DisplaySettings(
                language: language, interval: interval, theme: theme, rain: rain, original: !original)
        }
    }
}
