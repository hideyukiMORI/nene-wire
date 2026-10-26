/// 帯の桁の割り付けと、見出しの行・枠・状態の行の描き方（ADR 0006）。
struct StripLayout {
    let columns: Int
    let glyphs: FrameGlyphs
    let theme: Theme

    /// DATA の窓の内側の桁数（幅の 18%・16〜35 桁）。狭い端末でもフィードの名前が読めるよう 16 桁は取る（#13）。
    var dataWidth: Int {
        min(max(columns * 18 / 100, 16), 35)
    }

    /// 記事の枠の内側の桁数。
    var inner: Int {
        columns - dataWidth - 3
    }

    /// 本文を書ける桁数（左右に 2 桁ずつ空ける）。
    var textWidth: Int {
        inner - 4
    }

    /// 0 行目: 名前・回線の状態・日時。収まらなければ、飾り（電脳ニュース回線）・日付の順に落とす（#13）。
    func drawHeader(_ state: StripState, override: Segment?, into grid: inout Grid) {
        let rule = Segment("  " + glyphs.horizontal + glyphs.horizontal + "  ", theme.faint)
        let name = [Segment(" " + glyphs.marker, theme.accent), Segment("NENE//WIRE", theme.accent)]
        let link =
            override
            ?? Segment(
                state.feedsLive > 0 ? "LINK ESTABLISHED" : state.article == nil ? "LINK PENDING" : "LINK LOST",
                theme.dim)
        let tagline = [rule, Segment("電脳ニュース回線", theme.text)]
        let candidates = [
            name + tagline + [rule, link, rule, Segment(state.clock.stamp, theme.text)],
            name + [rule, link, rule, Segment(state.clock.stamp, theme.text)],
            name + [rule, link, rule, Segment(state.clock.time, theme.text)],
        ]
        let fitting = candidates.first { $0.reduce(0) { $0 + CellWidth.of($1.text) } <= columns } ?? candidates[2]
        fill(row: 0, with: theme.panel, into: &grid)
        grid.write(fitting, column: 0, row: 0, background: theme.panel)
    }

    /// 1 行目〜12 行目: 記事の枠と DATA の窓。色とラベルは演出が差し替える。
    func drawFrame(_ state: StripState, overrides: HudOverrides, into grid: inout Grid) {
        let frameColor = overrides.frame
        let label =
            overrides.label
            ?? Segment(
                " " + TextLayout.fit((state.article?.feedName ?? "NO SIGNAL").uppercased(), width: inner - 20) + " ",
                theme.accent)
        let name = label.text
        let clock = " " + state.clock.time + " "
        let tag = " DATA "
        let top: [Segment] = [
            Segment(glyphs.topLeft + glyphs.horizontal + "[", frameColor), label,
            Segment("]" + dashes(inner - 6 - CellWidth.of(name) - CellWidth.of(clock)) + "[", frameColor),
            Segment(clock, theme.dim),
            Segment("]" + glyphs.horizontal + glyphs.teeDown + glyphs.horizontal + "[", frameColor),
            Segment(tag, theme.faint),
            Segment("]" + dashes(dataWidth - 3 - CellWidth.of(tag)) + glyphs.topRight, frameColor),
        ]
        grid.write(top, column: 0, row: 1, background: theme.ground)
        for row in 2..<(2 + StripRenderer.bodyRows) {
            for column in [0, inner + 1, columns - 1] {
                grid.write([Segment(glyphs.vertical, frameColor)], column: column, row: row, background: theme.ground)
            }
        }
        let index = " " + Self.counter(state.position, of: state.count) + " "
        let bottom: [Segment] = [
            Segment(glyphs.bottomLeft + dashes(inner - 6 - CellWidth.of(index)) + "[", frameColor),
            Segment(index, theme.dim),
            Segment("]" + dashes(4) + glyphs.teeUp + dashes(dataWidth) + glyphs.bottomRight, frameColor),
        ]
        grid.write(bottom, column: 0, row: 2 + StripRenderer.bodyRows, background: theme.ground)
    }

    /// 13 行目: HUD のメッセージの行（取得の進み具合など）。
    func drawMessage(_ state: StripState, override: Segment?, into grid: inout Grid) {
        let label = " MSG "
        let width = columns - CellWidth.of(label) - 3
        let message = override ?? Segment(state.message, theme.dim)
        grid.write(
            [
                Segment(label, theme.faint), Segment(glyphs.pointer + " ", theme.accent),
                Segment(TextLayout.fit(message.text, width: width), message.color),
            ], column: 0, row: StripRenderer.height - 2, background: theme.ground)
    }

    /// 14 行目: 何件目か・ネット・取得・翻訳・速報・停止中・キー。狭ければ優先度の低いものから落とし、
    /// 何件目か・速報・停止中・`s 設定`・`q 終了` は必ず残す（#34）。
    func drawStatus(_ state: StripState, into grid: inout Grid) {
        let row = StripRenderer.height - 1
        let online = state.feedsLive > 0
        let failed = state.feeds.filter(\.isFailed).count
        let position = [Segment(" [\(Self.counter(state.position, of: state.count, separator: "/"))] ", theme.text)]
        let net = [
            Segment(" NET ", theme.faint),
            Segment(online ? glyphs.lamp + " ONLINE" : glyphs.lamp + " OFFLINE", online ? theme.accent : theme.dim),
        ]
        let feed = [Segment("   FEED ", theme.faint), Segment("\(state.feedsLive)/\(state.feeds.count)", theme.text)]
        let failure = failed > 0 ? [Segment("  取得失敗 \(failed)", theme.dim)] : []
        let fresh = state.pendingFresh > 0 ? [Segment("   速報 \(state.pendingFresh)", theme.warn)] : []
        let paused = state.paused ? [Segment("   " + glyphs.marker + "停止中", theme.accent)] : []
        func key(_ name: String, _ label: String) -> [Segment] {
            [Segment(name, theme.accent), Segment(" " + label + "  ", theme.dim)]
        }
        let groups: [[Segment]] = [
            position, net, feed, failure, translatorSegments(state.translator), fresh, paused,
            [Segment("   \(glyphs.vertical) ", theme.faint)], key("SPC", state.paused ? "再開" : "停止"),
            key(glyphs.arrows, "前後"), key("t", "翻訳"), key("s", "設定"),
            [Segment("q", theme.accent), Segment(" 終了", theme.dim)],
        ]
        // 落とす順: FEED・NET・取得失敗・TRANS・←→・SPC・t
        let line = LineFit.fit(groups, dropOrder: [2, 1, 3, 4, 9, 8, 10], width: columns)
        fill(row: row, with: theme.panel, into: &grid)
        grid.write(line, column: 0, row: row, background: theme.panel)
    }

    private func translatorSegments(_ status: TranslatorStatus) -> [Segment] {
        switch status {
        case .off:
            return [Segment("   TRANS ", theme.faint), Segment("未導入", theme.dim)]
        case .disabled:
            return [Segment("   TRANS ", theme.faint), Segment("オフ", theme.dim)]
        case .ready(let route, let pending, let busy):
            return [
                Segment("   TRANS ", theme.faint), Segment(route, theme.text),
                Segment(busy ? " " + glyphs.lamp : "", theme.accent),
            ]
                + (pending > 0 ? [Segment(" 待ち \(pending)", theme.dim)] : [])
        }
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
