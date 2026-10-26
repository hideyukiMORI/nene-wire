/// 帯の桁の割り付けと、見出しの行・枠・状態の行の描き方（ADR 0006）。
struct StripLayout {
    let columns: Int
    let glyphs: FrameGlyphs
    let theme: Theme

    /// DATA の窓の内側の桁数（幅の 18%・11〜35 桁）。
    var dataWidth: Int {
        min(max(columns * 18 / 100, 11), 35)
    }

    /// 記事の枠の内側の桁数。
    var inner: Int {
        columns - dataWidth - 3
    }

    /// 本文を書ける桁数（左右に 2 桁ずつ空ける）。
    var textWidth: Int {
        inner - 4
    }

    /// 0 行目: 名前・回線の状態・日時。
    func drawHeader(_ state: StripState, into grid: inout Grid) {
        let rule = glyphs.horizontal + glyphs.horizontal
        let link = state.feedsFetched > 0 ? "LINK ESTABLISHED" : "LINK LOST"
        fill(row: 0, with: theme.panel, into: &grid)
        grid.write(
            [
                Segment(" " + glyphs.marker, theme.accent), Segment("NENE//WIRE", theme.accent),
                Segment("  \(rule)  ", theme.faint), Segment("電脳ニュース回線", theme.text),
                Segment("  \(rule)  ", theme.faint), Segment(link, theme.dim), Segment("  \(rule)  ", theme.faint),
                Segment(state.clock.stamp, theme.text),
            ], column: 0, row: 0, background: theme.panel)
    }

    /// 1 行目〜13 行目: 記事の枠と DATA の窓。
    func drawFrame(_ state: StripState, into grid: inout Grid) {
        let name = " " + TextLayout.fit((state.article?.feedName ?? "NO SIGNAL").uppercased(), width: inner - 20) + " "
        let clock = " " + state.clock.time + " "
        let tag = " DATA "
        let top: [Segment] = [
            Segment(glyphs.topLeft + glyphs.horizontal + "[", theme.frame), Segment(name, theme.accent),
            Segment("]" + dashes(inner - 6 - CellWidth.of(name) - CellWidth.of(clock)) + "[", theme.frame),
            Segment(clock, theme.dim),
            Segment("]" + glyphs.horizontal + glyphs.teeDown + glyphs.horizontal + "[", theme.frame),
            Segment(tag, theme.faint),
            Segment("]" + dashes(dataWidth - 3 - CellWidth.of(tag)) + glyphs.topRight, theme.frame),
        ]
        grid.write(top, column: 0, row: 1, background: theme.ground)
        for row in 2..<(2 + StripRenderer.bodyRows) {
            for column in [0, inner + 1, columns - 1] {
                grid.write([Segment(glyphs.vertical, theme.frame)], column: column, row: row, background: theme.ground)
            }
        }
        let index = " " + Self.counter(state.position, of: state.count) + " "
        let bottom: [Segment] = [
            Segment(glyphs.bottomLeft + dashes(inner - 6 - CellWidth.of(index)) + "[", theme.frame),
            Segment(index, theme.dim),
            Segment("]" + dashes(4) + glyphs.teeUp + dashes(dataWidth) + glyphs.bottomRight, theme.frame),
        ]
        grid.write(bottom, column: 0, row: 2 + StripRenderer.bodyRows, background: theme.ground)
    }

    /// 14 行目: 何件目か・ネット・取得・キー。
    func drawStatus(_ state: StripState, into grid: inout Grid) {
        let row = StripRenderer.height - 1
        let online = state.feedsFetched > 0
        let failed = state.feedsTotal - state.feedsFetched
        var segments = [
            Segment(" [\(Self.counter(state.position, of: state.count, separator: "/"))] ", theme.text),
            Segment(" NET ", theme.faint),
            Segment(online ? glyphs.lamp + " ONLINE" : glyphs.lamp + " OFFLINE", online ? theme.accent : theme.dim),
            Segment("   FEED ", theme.faint), Segment("\(state.feedsFetched)/\(state.feedsTotal)", theme.text),
        ]
        if failed > 0 {
            segments.append(Segment("  取得失敗 \(failed)", theme.dim))
        }
        if state.paused {
            segments.append(Segment("   " + glyphs.marker + "停止中", theme.accent))
        }
        segments += [
            Segment("   \(glyphs.vertical) ", theme.faint), Segment("SPC", theme.accent),
            Segment(state.paused ? " 再開  " : " 停止  ", theme.dim), Segment(glyphs.arrows, theme.accent),
            Segment(" 前後  ", theme.dim), Segment("q", theme.accent), Segment(" 終了", theme.dim),
        ]
        fill(row: row, with: theme.panel, into: &grid)
        grid.write(segments, column: 0, row: row, background: theme.panel)
    }

    /// `042 / 180`。桁数は全部の件数に合わせ、少なくとも 3 桁。
    static func counter(_ position: Int, of count: Int, separator: String = " / ") -> String {
        let digits = max(String(count).count, 3)
        func padded(_ value: Int) -> String {
            let text = String(value)
            return String(repeating: "0", count: max(digits - text.count, 0)) + text
        }
        return padded(position) + separator + padded(count)
    }

    private func dashes(_ count: Int) -> String {
        String(repeating: glyphs.horizontal, count: max(count, 1))
    }

    private func fill(row: Int, with color: Rgb, into grid: inout Grid) {
        grid.write(
            [Segment(String(repeating: " ", count: columns), theme.text)], column: 0, row: row, background: color)
    }
}
