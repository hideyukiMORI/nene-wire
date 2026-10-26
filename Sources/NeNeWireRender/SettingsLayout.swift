import NeNeWireCore

/// 設定画面の割り付けと描き方（ADR 0011）。
struct SettingsLayout {
    let columns: Int
    let glyphs: FrameGlyphs
    let theme: Theme
    let editor: SettingsEditor

    /// 右の DISPLAY の枠の幅（罫線を含む）。
    var right: Int {
        min(max(columns * 36 / 100, 30), 48)
    }

    /// 左の FEEDS の枠の幅（罫線を含む）。
    var left: Int {
        columns - right
    }

    private var feedsFocused: Bool {
        editor.pane == .feeds
    }

    func drawHeader(clock: WallClock, into grid: inout Grid) {
        let rule = Segment("  " + glyphs.horizontal + glyphs.horizontal + "  ", theme.faint)
        let state =
            editor.isDirty ? Segment(glyphs.lamp + " 未保存の変更あり", theme.warn) : Segment("保存済み", theme.dim)
        fill(row: 0, with: theme.panel, into: &grid)
        grid.write(
            [
                Segment(" " + glyphs.marker, theme.accent), Segment("NENE//WIRE", theme.accent), rule,
                Segment("SETUP // 設定", theme.head), rule, state, rule, Segment(clock.time, theme.text),
            ], column: 0, row: 0, background: theme.panel)
    }

    func drawBoxes(into grid: inout Grid) {
        let enabled = editor.settings.feeds.filter(\.enabled).count
        let count = " \(editor.settings.feeds.count) 本 \(glyphs.separator) 有効 \(enabled) "
        box(Box(column: 0, width: left, title: " FEEDS ", note: count, focused: feedsFocused), into: &grid)
        box(Box(column: left, width: right, title: " DISPLAY ", note: "", focused: !feedsFocused), into: &grid)
    }

    /// フィードの一覧（選んでいる行が見えるように送る）。
    func drawFeeds(into grid: inout Grid) {
        let feeds = editor.settings.feeds
        let rows = SettingsRenderer.listRows
        let top = min(max(editor.selectedFeed - rows + 1, 0), max(feeds.count - rows, 0))
        let width = left - 4
        let nameWidth = min(max(width / 2, 12), 24)
        for (offset, index) in (top..<min(top + rows, feeds.count)).enumerated() {
            let feed = feeds[index]
            let selected = index == editor.selectedFeed
            let background = selected && feedsFocused ? theme.panel : theme.ground
            // ● は端末によって 2 桁に描かれて ] に重なるので、印は ASCII の x にする
            let check = feed.enabled ? "[x] " : "[ ] "
            let line = [
                Segment(selected ? glyphs.pointer + " " : "  ", theme.accent, background: background),
                Segment(check, feed.enabled ? theme.accent : theme.faint, background: background),
                Segment(
                    pad(TextLayout.fit(feed.name, width: nameWidth), to: nameWidth + 1),
                    selected ? theme.head : feed.enabled ? theme.text : theme.dim, background: background),
                Segment(
                    pad(TextLayout.fit(feed.url.host, width: width - nameWidth - 7), to: width - nameWidth - 7),
                    theme.dim, background: background),
            ]
            grid.write(line, column: 2, row: 2 + offset, background: theme.ground)
        }
        if feeds.isEmpty {
            grid.write([Segment("フィードが無い。a で足す", theme.dim)], column: 4, row: 2, background: theme.ground)
        }
    }

    /// 一覧の下の 3 行: 入力欄、または試した結果。
    func drawLower(into grid: inout Grid) {
        let width = left - 6
        grid.write(
            [Segment(String(repeating: glyphs.horizontal, count: left - 2), theme.faint)], column: 1, row: 9,
            background: theme.ground)
        guard case .form(let form) = editor.mode else {
            if let result = editor.testResult {
                grid.write(
                    [Segment("TEST ", theme.faint), Segment(TextLayout.fit(result, width: width - 5), theme.text)],
                    column: 3, row: 10, background: theme.ground)
            }
            return
        }
        let title = form.editing == nil ? "フィードを足す" : "フィードを直す"
        grid.write([Segment(title, theme.accent)], column: 3, row: 9, background: theme.ground)
        for (row, field, label, value) in [
            (10, FormField.name, "名前 ", form.name), (11, FormField.url, "URL  ", form.url),
        ] {
            let active = form.field == field
            let shown = TextLayout.fit(value, width: width - 7) + (active ? "█" : "")
            grid.write(
                [
                    Segment(label, theme.faint), Segment("[", theme.frame),
                    Segment(
                        pad(shown, to: width - 6), active ? theme.head : theme.dim,
                        background: active ? theme.panel : nil), Segment("]", theme.frame),
                ],
                column: 3, row: row, background: theme.ground)
        }
    }

    /// 表示の設定（← → で値を変える）。
    func drawDisplay(into grid: inout Grid) {
        let display = editor.settings.display
        let values = [
            OptionRow(option: .language, label: "表示する言語", value: SettingsRenderer.languageName(display.language)),
            OptionRow(option: .translate, label: "翻訳", value: display.translate ? "する" : "しない"),
            OptionRow(option: .interval, label: "1 件の表示時間", value: "\(display.interval) 秒"),
            OptionRow(option: .theme, label: "色のテーマ", value: display.theme),
            OptionRow(option: .rain, label: "文字の雨", value: display.rain ? "オン" : "オフ"),
            OptionRow(option: .original, label: "原文の見出し", value: display.original ? "添える" : "添えない"),
        ]
        for (offset, row) in values.enumerated() {
            let (option, label, value) = (row.option, row.label, row.value)
            let selected = option == editor.selectedOption && !feedsFocused
            let background = selected ? theme.panel : theme.ground
            grid.write(
                [
                    Segment(selected ? glyphs.pointer + " " : "  ", theme.accent, background: background),
                    Segment(pad(label, to: 16), selected ? theme.head : theme.text, background: background),
                    Segment("‹ ", theme.faint, background: background),
                    Segment(value, selected ? theme.accent : theme.text, background: background),
                    Segment(" ›", theme.faint, background: background),
                ], column: left + 2, row: 2 + offset, background: theme.ground)
        }
        let hint = "翻訳はいま英語から日本語だけ"
        grid.write(
            [Segment(TextLayout.fit(hint, width: right - 4), theme.faint)], column: left + 2, row: 9,
            background: theme.ground)
    }

    /// 知らせの行（確かめる問いと、入力の誤りや保存の結果）。
    func drawMessage(into grid: inout Grid) {
        let name =
            editor.settings.feeds.indices.contains(editor.selectedFeed)
            ? editor.settings.feeds[editor.selectedFeed].name : ""
        let message: Segment
        switch editor.mode {
        case .confirmDelete:
            message = Segment("!! 「\(name)」を消す？   y 消す  /  ほかのキー やめる", theme.warn)
        case .confirmClose:
            message = Segment("!! 保存していない変更がある。   w 保存して閉じる  /  x 捨てて閉じる  /  Esc 戻る", theme.warn)
        case .browse, .form:
            message = Segment(editor.notice ?? "", theme.dim)
        }
        grid.write(
            [
                Segment(" MSG ", theme.faint), Segment(glyphs.pointer + " ", theme.accent),
                Segment(TextLayout.fit(message.text, width: columns - 9), message.color),
            ],
            column: 0, row: StripRenderer.height - 2, background: theme.ground)
    }

    /// キーの行（いまの状態で使えるキー）。
    func drawKeys(into grid: inout Grid) {
        let keys: [(String, String)]
        switch editor.mode {
        case .form:
            keys = [("Tab", "次の欄"), ("Enter", "決める"), ("BS", "1 字消す"), ("Esc", "やめる")]
        case .confirmDelete, .confirmClose:
            keys = []
        case .browse where feedsFocused:
            keys = [
                ("↑↓", "選ぶ"), ("SPC", "有効/無効"), ("a", "足す"), ("e", "直す"), ("d", "消す"), ("t", "試す"), ("Tab", "表示の設定へ"),
                ("w", "保存"), ("Esc", "閉じる"),
            ]
        case .browse:
            keys = [("↑↓", "選ぶ"), ("←→", "値を変える"), ("Tab", "フィードへ"), ("w", "保存"), ("Esc", "閉じる")]
        }
        // 狭ければ前から落とす（w 保存・Esc 閉じる・Enter 決める など、最後の 2 つは必ず残す・#34）
        let groups = keys.map { [Segment(" " + $0.0, theme.accent), Segment(" " + $0.1 + " ", theme.dim)] }
        let line = LineFit.fit(groups, dropOrder: Array(0..<max(groups.count - 2, 0)), width: columns)
        fill(row: StripRenderer.height - 1, with: theme.panel, into: &grid)
        grid.write(line, column: 0, row: StripRenderer.height - 1, background: theme.panel)
    }

    /// 枠 1 つの置き場と見出し。
    private struct Box {
        let column: Int
        let width: Int
        let title: String
        let note: String
        let focused: Bool
    }

    /// 表示の設定の 1 行。
    private struct OptionRow {
        let option: DisplayOption
        let label: String
        let value: String
    }

    private func box(_ spec: Box, into grid: inout Grid) {
        let (column, width, title, note, focused) = (spec.column, spec.width, spec.title, spec.note, spec.focused)
        let color = focused ? theme.accent : theme.frame
        let dashes = max(width - 6 - CellWidth.of(title) - CellWidth.of(note), 1)
        grid.write(
            [
                Segment(glyphs.topLeft + glyphs.horizontal + "[", color),
                Segment(title, focused ? theme.accent : theme.dim),
                Segment("]" + String(repeating: glyphs.horizontal, count: dashes), color), Segment(note, theme.dim),
                Segment(glyphs.horizontal + glyphs.topRight, color),
            ], column: column, row: 1, background: theme.ground)
        for row in 2...11 {
            grid.write([Segment(glyphs.vertical, color)], column: column, row: row, background: theme.ground)
            grid.write(
                [Segment(glyphs.vertical, color)], column: column + width - 1, row: row, background: theme.ground)
        }
        grid.write(
            [
                Segment(
                    glyphs.bottomLeft + String(repeating: glyphs.horizontal, count: width - 2) + glyphs.bottomRight,
                    color)
            ],
            column: column, row: 12, background: theme.ground)
    }

    private func pad(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(width - CellWidth.of(text), 0))
    }

    private func fill(row: Int, with color: Rgb, into grid: inout Grid) {
        grid.write(
            [Segment(String(repeating: " ", count: columns), theme.text)], column: 0, row: row, background: color)
    }
}
