import NeNeWireRender

/// 格子を ANSI のバイト列にする（1 フレーム 1 回の `write` 用・ADR 0006）。
///
/// 帯は画面の最上部にある。前の格子と違う行だけを、行の頭から丸ごと書き直す（全角の文字の半分だけを書き換えない）。
/// 移植元: NeNe Reversi `Sources/NeNeReversiTerminal/FrameEncoder.swift`（コミット dc418eb）。
public enum FrameEncoder {
    /// `previous` が無いか大きさが違えば、全部の行を書く。
    public static func encode(_ grid: Grid, previous: Grid?, colors: ColorMode) -> [UInt8] {
        var out: [UInt8] = []
        let full = previous?.size != grid.size
        for row in 0..<grid.size.rows {
            let cells = grid.row(row)
            if !full, previous?.row(row) == cells {
                continue
            }
            out += Array("\u{1B}[\(row + 1);1H".utf8)
            out += encode(cells, colors: colors)
        }
        if !out.isEmpty {
            out += Array("\u{1B}[0m".utf8)
        }
        return out
    }

    private static func encode(_ cells: ArraySlice<Cell>, colors: ColorMode) -> [UInt8] {
        var out: [UInt8] = []
        var styled: Cell?  // いま端末に効いている色を持つセル
        for cell in cells {
            let character: Character
            switch cell.glyph {
            case .narrow(let narrow):
                character = narrow
            case .wide(let wide):
                character = wide
            case .continuation:
                continue
            }
            if styled?.foreground != cell.foreground || styled?.background != cell.background {
                out += sgr(cell.foreground, cell.background, colors)
                styled = cell
            }
            out += Array(String(character).utf8)
        }
        return out
    }

    private static func sgr(_ foreground: Rgb, _ background: Rgb, _ colors: ColorMode) -> [UInt8] {
        switch colors {
        case .trueColor:
            let fg = "38;2;\(foreground.red);\(foreground.green);\(foreground.blue)"
            let bg = "48;2;\(background.red);\(background.green);\(background.blue)"
            return Array("\u{1B}[\(fg);\(bg)m".utf8)
        case .palette256:
            return Array("\u{1B}[38;5;\(Palette256.nearest(foreground));48;5;\(Palette256.nearest(background))m".utf8)
        }
    }
}
