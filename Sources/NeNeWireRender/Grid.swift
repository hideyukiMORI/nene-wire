/// 帯 1 枚分の文字セルの格子。Render が作り、Terminal が前の格子との差分を書く。
/// 移植元: NeNe Reversi `Sources/NeNeReversiRender/Grid.swift`（コミット dc418eb）。全角の文字（2 セル）を扱うようにした。
public struct Grid: Sendable, Hashable {
    public let size: ScreenSize
    /// 格納が private なので、合成される memberwise init も private になる（外から格子を作る経路は `filled` だけ）。
    private var cells: [Cell]

    /// 全面を 1 つの色の空白で埋めた格子。
    static func filled(_ size: ScreenSize, foreground: Rgb, background: Rgb) -> Grid {
        let blank = Cell(glyph: .narrow(" "), foreground: foreground, background: background)
        return Grid(size: size, cells: Array(repeating: blank, count: size.columns * size.rows))
    }

    /// その位置のセル。格子の外を読むのはプログラムの欠陥。
    public subscript(column: Int, row: Int) -> Cell {
        precondition((0..<size.columns).contains(column) && (0..<size.rows).contains(row), "格子の外")
        return cells[row * size.columns + column]
    }

    /// 1 行の全部のセル。
    public func row(_ row: Int) -> ArraySlice<Cell> {
        precondition((0..<size.rows).contains(row), "格子の外")
        return cells[(row * size.columns)..<((row + 1) * size.columns)]
    }

    /// 色の付いた切れを左から続けて書き、書いた桁数を返す。行からはみ出す文字は書かない（全角の左半分だけを書かない）。
    @discardableResult
    mutating func write(_ segments: [Segment], column: Int, row: Int, background: Rgb) -> Int {
        var offset = 0
        for segment in segments {
            for character in segment.text {
                let width = CellWidth.of(character)
                guard width > 0 else {
                    continue
                }
                guard column + offset + width <= size.columns, (0..<size.rows).contains(row), column + offset >= 0
                else {
                    return offset
                }
                let colors = Cell(glyph: .narrow(" "), foreground: segment.color, background: background)
                place(character, width: width, at: row * size.columns + column + offset, colors: colors)
                offset += width
            }
        }
        return offset
    }

    /// 1 文字を `position`（行 × 桁数 ＋ 桁）に置く。色は `colors` から取る。
    /// 半分だけ上書きされる全角の文字は、残った半分を空白にする（端末に半分の文字を残さない）。
    private mutating func place(_ character: Character, width: Int, at position: Int, colors: Cell) {
        let column = position % size.columns
        let base = position - column
        for target in column..<(column + width) {
            breakWide(at: target, base: base)
        }
        cells[position] = Cell(
            glyph: width == 2 ? .wide(character) : .narrow(character), foreground: colors.foreground,
            background: colors.background)
        if width == 2 {
            cells[position + 1] = Cell(
                glyph: .continuation, foreground: colors.foreground, background: colors.background)
        }
    }

    private mutating func breakWide(at column: Int, base: Int) {
        let cell = cells[base + column]
        switch cell.glyph {
        case .narrow:
            return
        case .wide:
            if column + 1 < size.columns {
                cells[base + column + 1] = Cell(
                    glyph: .narrow(" "), foreground: cell.foreground, background: cell.background)
            }
        case .continuation:
            if column > 0 {
                let lead = cells[base + column - 1]
                cells[base + column - 1] = Cell(
                    glyph: .narrow(" "), foreground: lead.foreground, background: lead.background)
            }
        }
    }
}
