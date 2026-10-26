/// 要約欄の HTML を素の文字列にする（FR-08・ADR 0005）。タグを取り除き、文字参照を解決し、空白をまとめる。
///
/// 要約欄は「エスケープされた HTML」（`&lt;p&gt;`）でも「CDATA の中の HTML」でも来る。XML の字句解析が 1 段目の文字参照を解決したあとの文字列を受け取り、
/// ここでタグを除いてから、もう 1 段の文字参照を解決する。段落の区切りのタグ（`p` `br` `li` `div` `h1`〜`h6` など）は段落の切れ目にする
/// （句点で終わらないリード文を、次の段落と 1 文にしない）。書式文字（Unicode の Cf: ゼロ幅スペース・単語結合子など）は表示の桁を狂わせるので除く。
public enum PlainText {
    private static let blockTags: Set<String> = [
        "p", "br", "li", "div", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "tr", "ul", "ol",
    ]

    /// 素の文字列（段落は空白 1 つでつなぐ）。
    public static func from(html: String) -> String {
        paragraphs(html: html).joined(separator: " ")
    }

    /// 段落ごとの素の文字列（空の段落は除く）。
    public static func paragraphs(html: String) -> [String] {
        var paragraphs: [String] = []
        var current = String.UnicodeScalarView()
        var tag: String.UnicodeScalarView?
        for scalar in html.unicodeScalars {
            if var name = tag {
                if scalar == ">" {
                    tag = nil
                    current.append(" ")
                    if blockTags.contains(tagName(String(name))) {
                        paragraphs.append(String(current))
                        current = String.UnicodeScalarView()
                    }
                } else {
                    name.append(scalar)
                    tag = name
                }
            } else if scalar == "<" {
                tag = String.UnicodeScalarView()
            } else {
                current.append(scalar)
            }
        }
        paragraphs.append(String(current))
        return paragraphs.map(clean).filter { !$0.isEmpty }
    }

    /// タグの中身（`/p`・`br /`・`a href=...`）から小文字の名前を取り出す。
    private static func tagName(_ body: String) -> String {
        let trimmed = body.drop { $0 == "/" || $0 == " " }
        return String(trimmed.prefix { $0 != " " && $0 != "/" && $0 != "\t" && $0 != "\n" }).lowercased()
    }

    private static func clean(_ text: String) -> String {
        let decoded = CharacterReferences.decode(text)
        let visible = String(
            String.UnicodeScalarView(decoded.unicodeScalars.filter { $0.properties.generalCategory != .format }))
        return visible.collapsingSpaces
    }
}
