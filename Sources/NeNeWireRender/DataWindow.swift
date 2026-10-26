/// DATA の窓: フィードごとの様子を 1 行ずつ（FR-15・ADR 0007）。印・名前・件数。
enum DataWindow {
    /// 1 行の見た目: 印・その色・件数の欄。
    private struct Look {
        let mark: String
        let color: Rgb
        let count: String
    }

    static func lines(for feeds: [FeedRow], width: Int, glyphs: FrameGlyphs, theme: Theme) -> [[Segment]] {
        feeds.map { feed in
            let look = describe(feed, glyphs: glyphs, theme: theme)
            let name = TextLayout.fit(feed.name, width: max(width - 7, 1))
            let gap = String(repeating: " ", count: max(width - 3 - CellWidth.of(name) - CellWidth.of(look.count), 1))
            return [
                Segment(" " + look.mark + " ", look.color), Segment(name, feed.isLive ? theme.text : theme.dim),
                Segment(gap + look.count, theme.dim),
            ]
        }
    }

    /// 印・その色・件数の欄。取りに行っている最中は `~`、取れたら点灯、更新なしは件数だけ、失敗は `!`、未取得は区切り。
    private static func describe(_ feed: FeedRow, glyphs: FrameGlyphs, theme: Theme) -> Look {
        if feed.fetching {
            return Look(mark: "~", color: theme.accent, count: "...")
        }
        switch feed.health {
        case .pending:
            return Look(mark: glyphs.separator, color: theme.faint, count: "--")
        case .fetched(let count):
            return Look(mark: glyphs.lamp, color: theme.accent, count: String(count))
        case .unchanged(let count):
            return Look(mark: glyphs.lamp, color: theme.dim, count: String(count))
        case .failed:
            return Look(mark: "!", color: theme.head, count: "ERR")
        }
    }
}
