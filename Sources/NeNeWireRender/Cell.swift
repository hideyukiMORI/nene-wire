/// 端末の文字セル 1 つ。
public struct Cell: Sendable, Hashable {
    public let glyph: Glyph
    public let foreground: Rgb
    public let background: Rgb
}
