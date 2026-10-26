/// 記事の枠の中の、空白でない 1 文字（演出で並べ替えたり差し替えたりする単位）。
struct BodyCell: Sendable, Hashable {
    let column: Int
    let row: Int
    let character: Character
    let wide: Bool
    let foreground: Rgb
    let background: Rgb
}
