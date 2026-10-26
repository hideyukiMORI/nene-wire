/// 枠の字形（`FrameStyle` ごと）。
struct FrameGlyphs: Sendable, Hashable {
    let topLeft: String
    let topRight: String
    let teeDown: String
    let teeUp: String
    let bottomLeft: String
    let bottomRight: String
    let horizontal: String
    let vertical: String
    /// 行頭の印（受信の行・見出しの行）。
    let marker: String
    /// つながっているかの印。
    let lamp: String
    /// リンクの印。
    let pointer: String
    /// 項目の区切り。
    let separator: String
    /// 前後のキーの印。
    let arrows: String

    static func of(_ style: FrameStyle) -> FrameGlyphs {
        switch style {
        case .boxDrawing:
            return FrameGlyphs(
                topLeft: "┌", topRight: "┐", teeDown: "┬", teeUp: "┴", bottomLeft: "└", bottomRight: "┘",
                horizontal: "─", vertical: "│", marker: "▌", lamp: "●", pointer: "›", separator: "·", arrows: "←→")
        case .ascii:
            return FrameGlyphs(
                topLeft: "+", topRight: "+", teeDown: "+", teeUp: "+", bottomLeft: "+", bottomRight: "+",
                horizontal: "-", vertical: "|", marker: ">", lamp: "*", pointer: ">", separator: "/", arrows: "<>")
        }
    }
}
