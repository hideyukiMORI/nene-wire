/// 端末の文字セル 1 つ。
public struct Cell: Sendable, Hashable {
    public let glyph: Glyph
    public let foreground: Rgb
    public let background: Rgb

    /// 枠の中の 1 文字として取り出す。
    func bodyCell(column: Int, row: Int, character: Character, wide: Bool) -> BodyCell {
        BodyCell(
            column: column, row: row, character: character, wide: wide, foreground: foreground, background: background)
    }
}
