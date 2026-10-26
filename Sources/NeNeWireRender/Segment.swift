/// 色の付いた文字列のひと切れ。幅は `CellWidth` で数える（全角は 2 桁）。
struct Segment: Sendable, Hashable {
    let text: String
    let color: Rgb
    /// 地の色。nil なら書く先の地の色。
    let background: Rgb?

    init(_ text: String, _ color: Rgb, background: Rgb? = nil) {
        self.text = text
        self.color = color
        self.background = background
    }
}
