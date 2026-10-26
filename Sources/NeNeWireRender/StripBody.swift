import NeNeWireCore

/// 記事の枠の内側の 10 行（FR-14）。受信の行（速報なら印）・見出し（2 行まで）・出だし（残りの行）・リンク。
enum StripBody {
    /// 見出しに使う行数の上限。
    static let headlineRows = 2

    static func lines(for state: StripState, width: Int, glyphs: FrameGlyphs, theme: Theme) -> [[Segment]] {
        guard let article = state.article else {
            return empty(state, width: width, glyphs: glyphs, theme: theme)
        }
        var lines: [[Segment]] = []
        var received = "受信 " + StripLayout.counter(state.position, of: state.count).prefix { $0 != " " }
        if let published = article.published {
            received += " \(glyphs.separator) " + published.iso8601.dropFirst(11).prefix(5) + " UTC"
        }
        let badge = state.fresh ? "速報 " : ""
        lines.append([
            Segment(glyphs.marker, theme.accent), Segment(badge, theme.accent),
            Segment(TextLayout.fit(received, width: width - 1 - CellWidth.of(badge)), theme.dim),
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

    /// 手元に記事が 1 件も無いとき。取りに行っている間は回線の確立中、どれも失敗したなら取り直しを待っている旨。
    private static func empty(_ state: StripState, width: Int, glyphs: FrameGlyphs, theme: Theme) -> [[Segment]] {
        let failed = !state.feeds.isEmpty && state.feeds.allSatisfy { $0.isFailed && !$0.fetching }
        let title = failed ? "記事がありません" : "回線を確立中"
        let advice =
            failed
            ? "フィードを 1 本も取れていない。ネットの接続を確かめてください。しばらくすると自動で取り直します。"
            : "登録したフィードを順に取りに行っています。最初の記事が届きしだい流し始めます。"
        return [[Segment(glyphs.marker, theme.accent), Segment(title, theme.head)], []]
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
