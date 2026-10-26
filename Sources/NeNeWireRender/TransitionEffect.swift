/// 前置きの演出（ADR 0009）: 前の記事がパラパラ落ちる（案 F）・走査線で消える（案 A）・最初の記事の前に枠をなぞる（案 A）。
enum TransitionEffect {
    /// 前の記事の文字を、ばらばらの時刻に重力で落とす。`leaving` は前の記事を描いた格子。
    static func drop(_ grid: inout Grid, leaving: Grid, stage: Stage, moment: Moment) {
        let body = stage.body
        let theme = stage.theme
        body.clear(&grid)
        let bottom = BodyCanvas.rows.upperBound
        for (index, cell) in body.cells(of: leaving).enumerated() {
            let start = Int(Noise.unit(moment.seed, index, 17) * 600)
            let seconds = Double(moment.elapsed - start) / 1_000
            guard seconds > 0 else {
                body.put(&grid, String(cell.character), at: (cell.column, cell.row), color: cell.foreground)
                continue
            }
            let row = cell.row + Int(seconds * seconds * 28)
            guard row <= bottom else {
                continue
            }
            let tone: Rgb
            if seconds < 0.15 {
                tone = theme.flash
            } else if seconds < 0.4 {
                tone = theme.accent
            } else {
                tone = row > bottom - 2 ? theme.faint : theme.dim
            }
            body.put(&grid, String(cell.character), at: (cell.column, row), color: tone)
        }
        guard moment.elapsed > 500 else {
            return
        }
        for column in 1...stage.inner where Noise.unit(moment.seed, column, moment.elapsed / 33) > 0.85 {
            body.put(&grid, stage.fx.noise[3], at: (column, bottom), color: theme.faint)
        }
    }

    /// 走査線が上から下へ通り、通ったあとを消す。
    static func scan(_ grid: inout Grid, leaving: Grid, stage: Stage, elapsed: Int) {
        let body = stage.body
        let rows = BodyCanvas.rows
        let line = rows.lowerBound + min(max(elapsed, 0) * rows.count / Choreography.transition, rows.count - 1)
        body.clear(&grid)
        for cell in body.cells(of: leaving) where cell.row > line {
            body.put(&grid, String(cell.character), at: (cell.column, cell.row), color: cell.foreground)
        }
        for column in 1...stage.inner {
            body.put(
                &grid, stage.fx.scan, at: (column, line),
                color: column % 7 == 0 ? stage.theme.flash : stage.theme.accent)
        }
    }

    /// 枠の外周を左上から時計回りになぞって描く。まだなぞっていない所と、枠の中の仕切りは消しておく。
    static func trace(_ grid: inout Grid, stage: Stage, elapsed: Int) {
        let columns = stage.layout.columns
        let top = 1
        let bottom = BodyCanvas.rows.upperBound + 1
        var path: [(Int, Int)] = (0..<columns).map { ($0, top) }
        path += (top + 1..<bottom).map { (columns - 1, $0) }
        path += (0..<columns).reversed().map { ($0, bottom) }
        path += (top + 1..<bottom).reversed().map { (0, $0) }
        let shown = path.count * min(max(elapsed, 0), Choreography.trace) / Choreography.trace
        for (index, (column, row)) in path.enumerated() where index >= shown - 3 {
            let character: Character
            switch grid[column, row].glyph {
            case .narrow(let narrow), .wide(let narrow):
                character = narrow
            case .continuation:
                continue
            }
            let hidden = index >= shown
            grid.write(
                [Segment(hidden ? " " : String(character), hidden ? stage.theme.text : stage.theme.flash)],
                column: column, row: row, background: stage.theme.ground)
        }
        for row in BodyCanvas.rows {
            grid.write(
                [Segment(" ", stage.theme.text)], column: stage.inner + 1, row: row, background: stage.theme.ground)
        }
    }
}
