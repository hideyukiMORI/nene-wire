/// セルに入るもの。全角の文字は 2 つのセルを占め、右のセルは `continuation` になる（ADR 0006）。
public enum Glyph: Sendable, Hashable {
    /// 1 桁の文字。
    case narrow(Character)
    /// 2 桁の文字の左半分（文字そのものを持つ）。
    case wide(Character)
    /// 2 桁の文字の右半分（何も書かない）。
    case continuation
}
