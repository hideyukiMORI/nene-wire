/// 接続シーケンス（案 D・FR-20・ADR 0009）: 最初の記事が出るまで、枠の中に取得の進み具合をブートログとして打ち出し、
/// DATA の窓に 16 進のダンプを流す。
enum BootView {
    /// 1 秒に打ち出す文字数。
    static let typing = 60

    static func draw(_ grid: inout Grid, stage: Stage, log: [LogLine], global: Int) {
        let body = stage.body
        body.clear(&grid)
        for (offset, line) in log.suffix(BodyCanvas.rows.count).enumerated() {
            let typed = max(global - line.at, 0) * typing / 1_000
            let text = String(line.text.prefix(typed))
            let color = line.text.hasPrefix(">") ? stage.theme.text : stage.theme.dim
            body.put(
                &grid, TextLayout.fit(text, width: stage.layout.textWidth),
                at: (3, BodyCanvas.rows.lowerBound + offset), color: color)
        }
    }

    /// DATA の窓のフィードの行より下に、流れる 16 進のダンプ。
    static func hexStream(_ grid: inout Grid, stage: Stage, feeds: Int, global: Int) {
        let first = BodyCanvas.rows.lowerBound + feeds + 1
        guard first <= BodyCanvas.rows.upperBound else {
            return
        }
        for (offset, row) in (first...BodyCanvas.rows.upperBound).enumerated() {
            let address = (0x3F20 + (global / 80 + offset) * 16) & 0xFFFF
            var line = hex(address, digits: 4) + " "
            for byte in 0..<6 {
                line += hex(Int(Noise.unit(UInt64(address), byte) * 256), digits: 2) + " "
            }
            let color = row == BodyCanvas.rows.upperBound ? stage.theme.accent : stage.theme.faint
            grid.write(
                [Segment(TextLayout.fit(line, width: stage.layout.dataWidth - 1), color)], column: stage.inner + 3,
                row: row, background: stage.theme.ground)
        }
    }

    private static func hex(_ value: Int, digits: Int) -> String {
        let text = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(digits - text.count, 0)) + text
    }
}
