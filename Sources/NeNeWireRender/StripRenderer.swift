import NeNeWireCore

/// 帯（端末の幅いっぱい・高さ 15 行）を描く（FR-14・FR-15・FR-21・ADR 0006）。画面を作るのはここ 1 か所。
///
/// 上から: 見出しの行・枠の上辺・記事（左）と DATA の窓（右）の 10 行・枠の下辺・メッセージの行・状態の行（固定の割り付け・ADR 0007）。
/// 枠の幅は端末の桁数に合わせて伸び縮みし、DATA の窓は幅の 18%（11〜35 桁）でフィードごとの様子を出す。
public enum StripRenderer {
    /// 帯の高さ（施主の決定・Q9）。
    public static let height = 15
    /// これより狭い端末では「小さすぎる」とだけ出す。
    public static let minimumColumns = 72
    /// 枠の内側の行数。
    static let bodyRows = height - 5

    /// 帯の格子。高さは `height` と端末の行数の小さいほう。
    public static func render(_ state: StripState, size: ScreenSize, theme: Theme, traits: TerminalTraits) -> Grid {
        let rows = min(height, size.rows)
        var grid = Grid.filled(
            ScreenSize(columns: size.columns, rows: rows), foreground: theme.text, background: theme.ground)
        guard size.columns >= minimumColumns, size.rows >= height else {
            let message = "端末が小さすぎる（\(minimumColumns)×\(height) 以上に広げてください）"
            grid.write(
                [Segment(TextLayout.fit(message, width: size.columns), theme.accent)], column: 0, row: 0,
                background: theme.ground)
            return grid
        }
        let layout = StripLayout(columns: size.columns, glyphs: FrameGlyphs.of(traits.frame), theme: theme)
        layout.drawHeader(state, into: &grid)
        layout.drawFrame(state, into: &grid)
        for (offset, line) in StripBody.lines(for: state, width: layout.textWidth, glyphs: layout.glyphs, theme: theme)
            .enumerated()
        {
            grid.write(line, column: 3, row: 2 + offset, background: theme.ground)
        }
        for (offset, line) in DataWindow.lines(
            for: state.feeds, width: layout.dataWidth, glyphs: layout.glyphs, theme: theme
        )
        .prefix(bodyRows).enumerated() {
            grid.write(line, column: layout.inner + 2, row: 2 + offset, background: theme.ground)
        }
        layout.drawMessage(state, into: &grid)
        layout.drawStatus(state, into: &grid)
        return grid
    }
}
