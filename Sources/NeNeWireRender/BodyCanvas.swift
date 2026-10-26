/// 記事の枠の中（2〜11 行目・1〜inner 桁）の文字を集めて、消して、置き直す（ADR 0009）。
struct BodyCanvas {
    static let rows = 2...11

    let inner: Int
    let theme: Theme

    /// 枠の中の空白でない文字を、読む順（上の行から左から）に集める。
    func cells(of grid: Grid) -> [BodyCell] {
        var found: [BodyCell] = []
        for row in Self.rows {
            for column in 1...inner {
                let cell = grid[column, row]
                switch cell.glyph {
                case .narrow(let character) where character != " ":
                    found.append(cell.bodyCell(column: column, row: row, character: character, wide: false))
                case .wide(let character):
                    found.append(cell.bodyCell(column: column, row: row, character: character, wide: true))
                case .narrow, .continuation:
                    continue
                }
            }
        }
        return found
    }

    /// 枠の中（または指定した行）を地の色の空白にする。
    func clear(_ grid: inout Grid, rows: ClosedRange<Int> = rows) {
        for row in rows {
            grid.write(
                [Segment(String(repeating: " ", count: inner), theme.text)], column: 1, row: row,
                background: theme.ground)
        }
    }

    /// 文字列を置く（枠の中に収まらなければ置かない）。
    func put(_ grid: inout Grid, _ text: String, at position: (column: Int, row: Int), colors: CellColors) {
        guard Self.rows.contains(position.row), position.column >= 1,
            position.column + CellWidth.of(text) - 1 <= inner
        else {
            return
        }
        grid.write(
            [Segment(text, colors.foreground)], column: position.column, row: position.row,
            background: colors.background)
    }

    /// 地の色の上に置く。
    func put(_ grid: inout Grid, _ text: String, at position: (column: Int, row: Int), color: Rgb) {
        put(&grid, text, at: position, colors: CellColors(foreground: color, background: theme.ground))
    }
}
