import NeNeWireCore

/// 記事の枠の内側の 11 行（FR-14）。受信の行・見出し（2 行まで）・出だし（残りの行）・リンク。
enum StripBody {
    /// 見出しに使う行数の上限。
    static let headlineRows = 2

    static func lines(for state: StripState, width: Int, glyphs: FrameGlyphs, theme: Theme) -> [[Segment]] {
        guard let article = state.article else {
            return empty(width: width, glyphs: glyphs, theme: theme)
        }
        var lines: [[Segment]] = []
        var received = "受信 " + StripLayout.counter(state.position, of: state.count).prefix { $0 != " " }
        if let published = article.published {
            received += " \(glyphs.separator) " + published.iso8601.dropFirst(11).prefix(5) + " UTC"
        }
        lines.append([
            Segment(glyphs.marker, theme.accent), Segment(TextLayout.fit(received, width: width - 1), theme.dim),
        ])
        lines.append([])
        for line in clipped(TextLayout.wrap(article.headline, width: width), rows: headlineRows, width: width) {
            lines.append([Segment(line, theme.head)])
        }
        lines.append([])
        let ledeRows = StripRenderer.bodyRows - lines.count - 2
        for line in clipped(TextLayout.wrap(article.lede ?? "", width: width), rows: ledeRows, width: width) {
            lines.append([Segment(line, theme.text)])
        }
        while lines.count < StripRenderer.bodyRows - 1 {
            lines.append([])
        }
        lines.append([
            Segment(glyphs.pointer + " ", theme.accent),
            Segment(TextLayout.fit(article.link, width: width - 2), theme.dim),
        ])
        return lines
    }

    /// 手元に記事が 1 件も無いとき。
    private static func empty(width: Int, glyphs: FrameGlyphs, theme: Theme) -> [[Segment]] {
        let advice = "フィードを 1 本も取れなかった。ネットの接続を確かめて、起動し直してください。"
        return [[Segment(glyphs.marker, theme.accent), Segment("記事がありません", theme.head)], []]
            + TextLayout.wrap(advice, width: width).prefix(StripRenderer.bodyRows - 2).map { [Segment($0, theme.text)] }
    }

    /// 行数の上限で切り、切ったなら最後の行の末尾を `…` にする。
    private static func clipped(_ lines: [String], rows: Int, width: Int) -> [String] {
        guard lines.count > rows, rows > 0 else {
            return Array(lines.prefix(max(rows, 0)))
        }
        var kept = Array(lines.prefix(rows))
        kept[rows - 1] = TextLayout.fit(kept[rows - 1] + "……", width: width)
        return kept
    }
}
