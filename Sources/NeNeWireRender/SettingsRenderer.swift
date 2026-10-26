import NeNeWireCore

/// 設定画面（FR-22〜25・ADR 0011）。帯と同じ 15 行を、左のフィードの一覧（FEEDS）と右の表示の設定（DISPLAY）に分けて描く。
/// 上から: 見出しの行・枠の上辺・中身の 10 行・枠の下辺・知らせの行・キーの行。
public enum SettingsRenderer {
    /// 一覧に見せるフィードの行数（それより多ければ選んでいる行が見えるように送る）。
    static let listRows = 7

    public static func render(
        _ editor: SettingsEditor, clock: WallClock, size: ScreenSize, style: (theme: Theme, traits: TerminalTraits)
    ) -> Grid {
        let theme = style.theme
        guard size.columns >= StripRenderer.minimumColumns, size.rows >= StripRenderer.height else {
            var grid = Grid.filled(
                ScreenSize(columns: size.columns, rows: min(StripRenderer.height, size.rows)), foreground: theme.text,
                background: theme.ground)
            grid.write(
                [Segment(TextLayout.fit("端末が小さすぎる", width: size.columns), theme.accent)], column: 0, row: 0,
                background: theme.ground)
            return grid
        }
        let layout = SettingsLayout(
            columns: size.columns, glyphs: FrameGlyphs.of(style.traits.frame), theme: theme, editor: editor)
        var grid = Grid.filled(
            ScreenSize(columns: size.columns, rows: StripRenderer.height), foreground: theme.text,
            background: theme.ground)
        layout.drawHeader(clock: clock, into: &grid)
        layout.drawBoxes(into: &grid)
        layout.drawFeeds(into: &grid)
        layout.drawLower(into: &grid)
        layout.drawDisplay(into: &grid)
        layout.drawMessage(into: &grid)
        layout.drawKeys(into: &grid)
        return grid
    }

    /// 言語のコードの表示名（FR-24）。
    static func languageName(_ code: String) -> String {
        let names = [
            "ja": "日本語", "en": "English", "zh": "中文", "ko": "한국어", "fr": "Français", "de": "Deutsch", "es": "Español",
        ]
        return names[code] ?? code
    }
}
