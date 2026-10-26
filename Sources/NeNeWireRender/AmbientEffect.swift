/// HUD の呼吸（案 E・ADR 0009）: いつも出ている小さな動き。見出しの行を往復する光・受信の印の点滅・
/// 枠の下辺の導火線（次の記事までの残り）・DATA の窓の文字の雨と同期までの残りと稼働時間。
enum AmbientEffect {
    /// 見出しの行の区切りと空白の上を、光が往復する。
    static func sweep(_ grid: inout Grid, stage: Stage, global: Int) {
        let columns = stage.layout.columns
        let span = max(columns - 1, 1)
        let travel = (global * 30 / 1_000) % (span * 2)
        let head = travel < span ? travel : span * 2 - travel
        for trail in 0..<6 {
            let column = travel < span ? head - trail : head + trail
            guard (0..<columns).contains(column) else {
                continue
            }
            switch grid[column, 0].glyph {
            case .narrow(let character) where character == " " || String(character) == stage.layout.glyphs.horizontal:
                let glyph = stage.fx.sweep[min(trail / 2, 2)]
                let color = trail == 0 ? stage.theme.flash : stage.theme.accent
                grid.write([Segment(glyph, color)], column: column, row: 0, background: stage.theme.panel)
            case .narrow, .wide, .continuation:
                continue
            }
        }
    }

    /// 受信の印を 0.5 秒ごとに明滅させる。
    static func blink(_ grid: inout Grid, stage: Stage, global: Int) {
        guard case .narrow(let character) = grid[3, 2].glyph, String(character) == stage.layout.glyphs.marker else {
            return
        }
        let color = (global / 500) % 2 == 0 ? stage.theme.accent : stage.theme.dim
        grid.write([Segment(String(character), color)], column: 3, row: 2, background: stage.theme.ground)
    }

    /// 枠の下辺の左を導火線にする。残り時間のぶんだけ太い線で、燃えた所は元の線。
    static func fuse(_ grid: inout Grid, stage: Stage, remaining: Double) {
        let length = 24
        let lit = Int(Double(length) * min(max(remaining, 0), 1))
        let row = BodyCanvas.rows.upperBound + 1
        guard lit > 0 else {
            return
        }
        grid.write(
            [Segment(String(repeating: stage.fx.fuse, count: lit), stage.theme.dim)], column: 1, row: row,
            background: stage.theme.ground)
    }

    /// DATA の窓の、フィードの行より下: 文字の雨と、同期までの残りと稼働時間。
    static func dataWindow(_ grid: inout Grid, stage: Stage, feeds: Int, motion: Motion) {
        let left = stage.inner + 2
        let width = stage.layout.dataWidth
        let last = BodyCanvas.rows.upperBound
        let firstRain = BodyCanvas.rows.lowerBound + feeds + 1
        if firstRain <= last - 2 {
            DataRain.draw(&grid, stage: stage, rows: firstRain...(last - 2), global: motion.global)
        }
        let spinner = stage.fx.spinner[(motion.global / 160) % stage.fx.spinner.count]
        let sync = motion.syncIn.map { " SYNC \(two($0 / 60)):\(two($0 % 60))" } ?? " SYNC --:--"
        let up = "  UP  \(two(motion.uptime / 3_600)):\(two(motion.uptime / 60 % 60)):\(two(motion.uptime % 60))"
        grid.write(
            [Segment(TextLayout.fit(spinner + sync, width: width), stage.theme.dim)], column: left, row: last - 1,
            background: stage.theme.ground)
        grid.write(
            [Segment(TextLayout.fit(up, width: width), stage.theme.faint)], column: left, row: last,
            background: stage.theme.ground)
    }

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
