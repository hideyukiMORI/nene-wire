/// DATA の窓に降る文字の雨（FR-18・案 E・ADR 0009）。列ごとに速さと長さが違い、先頭ほど明るい。
enum DataRain {
    static func draw(_ grid: inout Grid, stage: Stage, rows: ClosedRange<Int>, global: Int) {
        let left = stage.inner + 2
        let span = rows.count
        let seconds = Double(global) / 1_000
        for lane in 0..<stage.layout.dataWidth {
            let speed = 3 + Noise.unit(1, lane, 1) * 6
            let length = 3 + Int(Noise.unit(1, lane, 2) * 5)
            let head = Int(seconds * speed + Noise.unit(1, lane, 3) * 40) % (span + length)
            for step in 0..<length {
                let row = rows.lowerBound + head - step
                guard rows.contains(row) else {
                    continue
                }
                let tone = step == 0 ? 4 : step < 2 ? 3 : step < 4 ? 2 : 1
                let glyph = Noise.pick(FxGlyphs.rain, 2, lane * 31 + row, global / 125)
                grid.write(
                    [Segment(String(glyph), stage.theme.rain[tone])], column: left + lane, row: row,
                    background: stage.theme.ground)
            }
        }
    }
}
