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
    public let switches: DisplaySwitches

    /// 文字の雨（FR-18）。
    public var rain: Bool {
        switches.rain
    }

    /// 訳したときに原文の見出しを添えるか（FR-14）。
    public var original: Bool {
        switches.original
    }

    /// 表示の言語と違う記事を訳すか。
    public var translate: Bool {
        switches.translate
    }

    private init(language: String, interval: Int, theme: String, switches: DisplaySwitches) {
        self.language = language
        self.interval = interval
        self.theme = theme
        self.switches = switches
    }

    /// 既定（日本語・12 秒・PHOSPHOR・雨あり・原文あり・翻訳する）。
    public static let defaults = DisplaySettings(language: "ja", interval: 12, theme: "PHOSPHOR", switches: .defaults)

    /// 値から作る。選べる値の外なら nil。
    public static func make(language: String, interval: Int, theme: String, switches: DisplaySwitches)
        -> DisplaySettings?
    {
        guard languages.contains(language), intervals.contains(interval), themes.contains(theme) else {
            return nil
        }
        return DisplaySettings(language: language, interval: interval, theme: theme, switches: switches)
    }

    /// `option` 番目の項目を、選べる値の列の中で `step` だけ動かしたもの（端では巡る。オン／オフは裏返す）。
    public func stepping(_ option: DisplayOption, by step: Int) -> DisplaySettings {
        func cycle<Value: Equatable>(_ values: [Value], _ current: Value) -> Value {
            let index = values.firstIndex(of: current) ?? 0
            return values[((index + step) % values.count + values.count) % values.count]
        }
        let (rain, original, translate) = (switches.rain, switches.original, switches.translate)
        switch option {
        case .language:
            return with(language: cycle(Self.languages, language))
        case .translate:
            return with(switches: DisplaySwitches(rain: rain, original: original, translate: !translate))
        case .interval:
            return with(interval: cycle(Self.intervals, interval))
        case .theme:
            return with(theme: cycle(Self.themes, theme))
        case .rain:
            return with(switches: DisplaySwitches(rain: !rain, original: original, translate: translate))
        case .original:
            return with(switches: DisplaySwitches(rain: rain, original: !original, translate: translate))
        }
    }

    /// 翻訳だけを裏返したもの（帯の表示中の `t`）。
    public var togglingTranslation: DisplaySettings {
        stepping(.translate, by: 1)
    }

    private func with(
        language: String? = nil, interval: Int? = nil, theme: String? = nil, switches: DisplaySwitches? = nil
    ) -> DisplaySettings {
        DisplaySettings(
            language: language ?? self.language, interval: interval ?? self.interval, theme: theme ?? self.theme,
            switches: switches ?? self.switches)
    }
}
