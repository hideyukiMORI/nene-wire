/// 電脳ノイズ（案 B・ADR 0009）: 静止中に一瞬だけ信号が乱れる。見出しの色ずれ・1 行の横ずれ・ブロックのノイズ・反転の帯。
enum GlitchEffect {
    /// 見出しの 1 行目。
    static let headlineRow = 4

    static func apply(_ grid: inout Grid, stage: Stage, moment: Moment) {
        let body = stage.body
        let theme = stage.theme
        let frame = moment.elapsed / 33
        let cells = body.cells(of: grid)
        let headline = cells.filter { $0.row == headlineRow }
        let shift = Int(Noise.unit(moment.seed, 21, frame) * 9) - 4
        // 色ずれ: 見出しを 2 色で 1 桁ずつずらして重ね、その上に本物を置き直す
        for (offset, color) in zip([-1, 1], theme.split) {
            for cell in headline {
                body.put(&grid, String(cell.character), at: (cell.column + offset + shift, cell.row), color: color)
            }
        }
        for cell in headline {
            body.put(&grid, String(cell.character), at: (cell.column + shift, cell.row), color: cell.foreground)
        }
        // 1 行の横ずれ
        let row = BodyCanvas.rows.lowerBound + 4 + Int(Noise.unit(moment.seed, 22, frame) * 3)
        let moved = cells.filter { $0.row == row }
        grid.write(
            [Segment(String(repeating: " ", count: stage.inner), theme.text)], column: 1, row: row,
            background: theme.ground)
        for cell in moved {
            body.put(&grid, String(cell.character), at: (cell.column - shift * 2, cell.row), color: cell.foreground)
        }
        noise(&grid, stage: stage, frame: frame, seed: moment.seed)
        invert(&grid, stage: stage, row: row + 1)
    }

    /// ブロックのノイズを 40 個散らす。
    private static func noise(_ grid: inout Grid, stage: Stage, frame: Int, seed: UInt64) {
        for index in 0..<40 {
            let column = 1 + Int(Noise.unit(seed, index * 2, frame) * Double(stage.inner))
            let row =
                BodyCanvas.rows.lowerBound + Int(Noise.unit(seed, index * 2 + 1, frame) * Double(BodyCanvas.rows.count))
            let color = index % 3 == 0 ? stage.theme.split[1] : stage.theme.accent
            stage.body.put(&grid, stage.fx.noise[index % 4], at: (column, row), color: color)
        }
    }

    /// 1 行を反転する（文字は地の色・地は強調の色）。
    private static func invert(_ grid: inout Grid, stage: Stage, row: Int) {
        guard BodyCanvas.rows.contains(row) else {
            return
        }
        var line = ""
        for column in 1...stage.inner {
            switch grid[column, row].glyph {
            case .narrow(let character), .wide(let character):
                line.append(character)
            case .continuation:
                continue
            }
        }
        grid.write([Segment(line, stage.theme.ground)], column: 1, row: row, background: stage.theme.accent)
    }
}
