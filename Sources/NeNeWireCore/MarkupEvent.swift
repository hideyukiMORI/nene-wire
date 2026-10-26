/// XML を先頭から読んだときの出来事（ADR 0005）。処理命令・コメント・文書型宣言は出来事にしない。
public enum MarkupEvent: Sendable, Hashable {
    /// 開きタグ。空要素（`<a/>`）は開きタグと閉じタグの 2 つの出来事になる。
    case open(name: String, attributes: [MarkupAttribute])
    case close(name: String)
    /// 文字列（文字参照は解決済み・CDATA の中身はそのまま）。
    case text(String)
}
