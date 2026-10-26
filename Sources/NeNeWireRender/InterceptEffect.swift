/// 緊急傍受（案 C・ADR 0009）: 速報が割り込む前に、枠の中を警告の縞と流れる帯で埋める。
enum InterceptEffect {
    static let banner = "  ■ INTERCEPT ■ 緊急傍受 ■ PRIORITY: ALPHA ■ 全回線に割り込み ■"

    static func alarm(_ grid: inout Grid, stage: Stage, elapsed: Int) {
        let theme = stage.theme
        let rows = BodyCanvas.rows
        let pulse = (elapsed / 125) % 2 == 0
        for row in rows {
            if row == rows.lowerBound || row == rows.upperBound {
                var stripe = ""
                for column in 1...stage.inner {
                    stripe += stage.fx.hazard[((column + elapsed / 50) % 4) / 2]
                }
                grid.write([Segment(stripe, theme.warnDeep)], column: 1, row: row, background: theme.warn)
            } else {
                let dark = row % 2 == 0 && pulse
                grid.write(
                    [Segment(String(repeating: " ", count: stage.inner), theme.text)], column: 1, row: row,
                    background: dark ? theme.warnDeep : theme.ground)
            }
        }
        let line = marquee(width: stage.inner - 2, offset: elapsed * 30 / 1_000)
        for row in [6, 7] {
            grid.write([Segment(line, theme.ground)], column: 2, row: row, background: theme.warn)
        }
    }

    /// 帯の文字列を `offset` 桁ずらして、`width` 桁ちょうどに切り出す。
    static func marquee(width: Int, offset: Int) -> String {
        let unit = Array(banner)
        let period = CellWidth.of(banner)
        var skip = offset % max(period, 1)
        var index = 0
        while skip > 0 {
            skip -= CellWidth.of(unit[index % unit.count])
            index += 1
        }
        var line = skip < 0 ? " " : ""
        while CellWidth.of(line) < width {
            let next = unit[index % unit.count]
            if CellWidth.of(line) + CellWidth.of(next) > width {
                line += " "
                continue
            }
            line.append(next)
            index += 1
        }
        return line
    }
}
