/// くるくる確定（案 A・A1〜A3・ADR 0009）: 枠の中の文字が、記号がくるくる変わる状態を経て正しい文字に止まる。
/// 文字ごとに「現れる時刻」と「止まる時刻」を決め、その間は全角の位置にカタカナ、半角の位置に 16 進と記号を出す。止まった瞬間は光る。
/// 受信の行（確定の最中は「復号中 NN%」と進み具合）はくるくるさせない。
enum SpinEffect {
    /// 記号を差し替える間隔（1 秒に 24 回）。
    static let tick = 42
    /// 止まった直後に光っている長さ。
    static let flash = 70

    /// 止まり方と、時刻を決める材料。
    struct Plan {
        let count: Int
        let inner: Int
        let order: SpinOrder
        let seed: UInt64
    }

    /// `moment.elapsed` は確定が始まってからのミリ秒。
    static func apply(_ grid: inout Grid, stage: Stage, moment: Moment, order: SpinOrder) {
        let body = stage.body
        let spun = (BodyCanvas.rows.lowerBound + 1)...BodyCanvas.rows.upperBound
        let cells = body.cells(of: grid).filter { spun.contains($0.row) }
        guard !cells.isEmpty else {
            return
        }
        body.clear(&grid, rows: spun)
        let plan = Plan(count: cells.count, inner: stage.inner, order: order, seed: moment.seed)
        let elapsed = moment.elapsed
        for (index, cell) in cells.enumerated() {
            let (appear, lock) = times(of: index, cell: cell, plan: plan)
            guard elapsed >= appear else {
                continue
            }
            let position = (column: cell.column, row: cell.row)
            if elapsed >= lock {
                let color = elapsed - lock < flash ? stage.theme.flash : cell.foreground
                body.put(
                    &grid, String(cell.character), at: position,
                    colors: CellColors(foreground: color, background: cell.background))
            } else {
                let frame = elapsed / tick
                let glyph = Noise.pick(cell.wide ? FxGlyphs.wideSpin : FxGlyphs.narrowSpin, moment.seed, index, frame)
                let bright = Noise.unit(moment.seed, index + 7_919, frame) > 0.8
                body.put(
                    &grid, String(glyph), at: position,
                    colors: CellColors(
                        foreground: bright ? stage.theme.flash : stage.theme.accent, background: cell.background))
            }
        }
    }

    /// i 番目の文字の現れる時刻と止まる時刻（確定が始まってからのミリ秒）。どれも `Choreography.entry` の中に収まる。
    static func times(of index: Int, cell: BodyCell, plan: Plan) -> (Int, Int) {
        let jitter = Noise.unit(plan.seed, index, 11)
        switch plan.order {
        case .cascade:
            let step = min(45, 2_000 / max(plan.count, 1))
            let appear = index * step
            return (appear, appear + 220 + Int(jitter * 120))
        case .sweep:
            let appear = (cell.row - BodyCanvas.rows.lowerBound) * 60
            let step = min(35, 1_500 / max(plan.inner, 1))
            return (appear, appear + 500 + cell.column * step)
        case .scatter:
            let appear = Int(Noise.unit(plan.seed, index, 13) * 400)
            return (appear, 400 + Int(jitter * 1_800))
        }
    }
}
