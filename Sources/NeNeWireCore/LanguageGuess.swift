/// 記事の言語の判定（FR-09・ADR 0010）。文字の種類だけで決める: かなか漢字が字の 2 割以上なら日本語、ラテン文字が 8 割以上なら英語、どちらでもなければ分からない。
/// 翻訳の手段に入れているのは英語から日本語へのモデルだけなので、判定するのもこの 2 つだけ。
public enum LanguageGuess {
    public static let japanese = "ja"
    public static let english = "en"

    /// 判定した言語のコード。分からなければ nil（原文のまま出す）。
    public static func of(_ text: String) -> String? {
        var letters = 0
        var japanese = 0
        var latin = 0
        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            letters += 1
            let value = scalar.value
            if (0x3040...0x30FF).contains(value) || (0x4E00...0x9FFF).contains(value)
                || (0x3400...0x4DBF).contains(value)
            {
                japanese += 1
            } else if value < 0x0250 {
                latin += 1
            }
        }
        guard letters > 0 else {
            return nil
        }
        if japanese * 5 >= letters {
            return Self.japanese
        }
        return latin * 5 >= letters * 4 ? Self.english : nil
    }
}
