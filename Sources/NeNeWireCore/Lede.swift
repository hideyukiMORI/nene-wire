/// 出だし: 要約欄から作る、記事の先頭の 2〜3 文（FR-08・ADR 0005）。
public enum Lede {
    /// 長さの上限（文字数）。
    static let maximumLength = 250
    /// 文の数の上限。
    static let maximumSentences = 3

    /// 要約の段落（素の文字列）と見出しから出だしを作る。要約が空か、見出しと同じ（あるいは見出しに含まれる）なら nil。
    public static func make(paragraphs: [String], headline: String) -> String? {
        let text = paragraphs.map(\.collapsingSpaces).filter { !$0.isEmpty }.joined(separator: " ")
        let title = headline.collapsingSpaces
        guard !text.isEmpty, text != title, !title.contains(text) else {
            return nil
        }
        var lede = ""
        for sentence in paragraphs.flatMap(sentences).prefix(maximumSentences) {
            // 日本語の句点で終わる文は空白なしでつなぐ
            let separator = lede.isEmpty || "。！？".contains(lede.last ?? " ") ? "" : " "
            let candidate = lede + separator + sentence
            guard candidate.count <= maximumLength else {
                break
            }
            lede = candidate
        }
        if lede.isEmpty {
            lede = String(text.prefix(maximumLength - 1)).trimmingSpaces + "\u{2026}"
        }
        return lede
    }

    /// 文に分ける。句点（`。` `！` `？`）は直後で、`.` `!` `?` は直後が空白か終わりのときに切る。
    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        for (index, char) in chars.enumerated() {
            current.append(char)
            let next = index + 1 < chars.count ? chars[index + 1] : " "
            let ends = "。！？".contains(char) || (".!?".contains(char) && next == " ")
            if ends {
                result.append(current.trimmingSpaces)
                current = ""
            }
        }
        let rest = current.trimmingSpaces
        if !rest.isEmpty {
            result.append(rest)
        }
        return result.filter { !$0.isEmpty }
    }
}
