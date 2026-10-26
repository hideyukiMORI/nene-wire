import NeNeWireCore

/// 帯（端末の幅いっぱい・高さ 15 行）を描く（FR-14・FR-15・FR-21・ADR 0006・0007・0009）。画面を作るのはここ 1 か所。
///
/// 上から: 見出しの行・枠の上辺・記事（左）と DATA の窓（右）の 10 行・枠の下辺・メッセージの行・状態の行（固定の割り付け）。
/// 枠の幅は端末の桁数に合わせて伸び縮みし、DATA の窓は幅の 18%（16〜35 桁）でフィードごとの様子を出す。
/// 演出は状態の `motion`（経過時間と種）だけから決まる。同じ状態なら同じ格子になる。
public enum StripRenderer {
    /// 帯の高さ（施主の決定・Q9）。
    public static let height = 15
    /// これより狭い端末では「小さすぎる」とだけ出す。
    public static let minimumColumns = 72
    /// 枠の内側の行数。
    static let bodyRows = height - 5

    /// 帯の格子。高さは `height` と端末の行数の小さいほう。
    public static func render(_ state: StripState, size: ScreenSize, theme: Theme, traits: TerminalTraits) -> Grid {
        guard size.columns >= minimumColumns, size.rows >= height else {
            var grid = Grid.filled(
                ScreenSize(columns: size.columns, rows: min(height, size.rows)), foreground: theme.text,
                background: theme.ground)
            let message = "端末が小さすぎる（\(minimumColumns)×\(height) 以上に広げてください）"
            grid.write(
                [Segment(TextLayout.fit(message, width: size.columns), theme.accent)], column: 0, row: 0,
                background: theme.ground)
            return grid
        }
        let stage = Stage(
            layout: StripLayout(columns: size.columns, glyphs: FrameGlyphs.of(traits.frame), theme: theme),
            fx: FxGlyphs.of(traits.frame))
        let entry = Choreography.entryElapsed(fresh: state.fresh, motion: state.motion)
        let decoding = entry.flatMap { $0 < Choreography.entry ? $0 * 100 / Choreography.entry : nil }
        var grid = base(
            state, stage: stage, overrides: overrides(state, stage: stage, entry: entry), decoding: decoding)
        animateBody(&grid, state: state, stage: stage, entry: entry)
        animateHud(&grid, state: state, stage: stage, entry: entry)
        return grid
    }

    /// 合成ルートが細かく描き直すべきか（前置き・確定・ノイズの最中）。
    public static func isBusy(_ state: StripState) -> Bool {
        state.article == nil || Choreography.isBusy(fresh: state.fresh, motion: state.motion)
    }

    /// 演出の前の、止まった帯。
    static func base(_ state: StripState, stage: Stage, overrides: HudOverrides, decoding: Int?) -> Grid {
        let layout = stage.layout
        var grid = Grid.filled(
            ScreenSize(columns: layout.columns, rows: height), foreground: stage.theme.text,
            background: stage.theme.ground)
        layout.drawHeader(state, override: overrides.link, into: &grid)
        layout.drawFrame(state, overrides: overrides, into: &grid)
        for (offset, line) in StripBody.lines(for: state, stage: stage, decoding: decoding).enumerated() {
            grid.write(line, column: 3, row: 2 + offset, background: stage.theme.ground)
        }
        for (offset, line) in DataWindow.lines(
            for: state.feeds, width: layout.dataWidth, glyphs: layout.glyphs, theme: stage.theme
        )
        .prefix(bodyRows).enumerated() {
            grid.write(line, column: layout.inner + 2, row: 2 + offset, background: stage.theme.ground)
        }
        layout.drawMessage(state, override: overrides.message, into: &grid)
        layout.drawStatus(state, into: &grid)
        return grid
    }

    /// 速報の警告・電脳ノイズ・枠の明滅が、見出しの行・枠・メッセージの行に出す分。
    static func overrides(_ state: StripState, stage: Stage, entry: Int?) -> HudOverrides {
        let theme = stage.theme
        let motion = state.motion
        let breathing = [theme.frame, theme.dim, theme.frame, theme.faint][(motion.global / 500) % 4]
        guard state.article != nil else {
            let blink = (motion.global / 333) % 2 == 0 ? theme.dim : theme.faint
            let link = state.feedsLive > 0 ? nil : Segment("LINK PENDING", blink)
            return HudOverrides(
                link: link, frame: breathing, label: Segment(" BOOT SEQUENCE ", theme.dim), message: nil)
        }
        if state.fresh, (entry ?? 0) < Choreography.entry + 2_000 {
            let pulse = (motion.article / 250) % 2 == 0 ? theme.warn : theme.frame
            let alarm = entry == nil
            let feed = state.article?.feedName ?? ""
            return HudOverrides(
                link: alarm ? Segment("!! INTERCEPT !!", theme.warn) : nil, frame: pulse,
                label: Segment(" 速報 // BREAKING ", theme.warn),
                message: Segment("!! 傍受  \(feed)  ::  優先度 ALPHA  ::  通常の巡回を中断", theme.warn))
        }
        if Choreography.inBurst(fresh: state.fresh, motion: motion) {
            let lost = "S1GN4L " + String(repeating: stage.fx.noise[2], count: 4) + " L0ST"
            return HudOverrides(
                link: Segment(lost, theme.split[1]), frame: breathing, label: nil,
                message: Segment("!! 信号に干渉  ::  ゴーストを検知  ::  補正中", theme.split[1]))
        }
        return HudOverrides(link: nil, frame: breathing, label: nil, message: nil)
    }

    /// 枠の中の演出: ブートログ・前置き（警告・切り替え・枠をなぞる）・くるくる確定・電脳ノイズ。
    static func animateBody(_ grid: inout Grid, state: StripState, stage: Stage, entry: Int?) {
        let motion = state.motion
        guard state.article != nil else {
            if !state.log.isEmpty {
                BootView.draw(&grid, stage: stage, log: state.log, global: motion.global)
            }
            return
        }
        guard let entry else {
            prelude(&grid, state: state, stage: stage)
            return
        }
        let moment = Moment(elapsed: entry, seed: motion.seed)
        if entry < Choreography.entry {
            SpinEffect.apply(&grid, stage: stage, moment: moment, order: Choreography.spinOrder(motion))
        }
        if Choreography.inBurst(fresh: state.fresh, motion: motion) {
            GlitchEffect.apply(&grid, stage: stage, moment: moment)
        }
    }

    /// 確定の前の前置き。
    static func prelude(_ grid: inout Grid, state: StripState, stage: Stage) {
        let motion = state.motion
        if state.fresh {
            InterceptEffect.alarm(&grid, stage: stage, elapsed: motion.article)
        } else if let leaving = motion.leaving {
            let old = base(
                state.showing(leaving), stage: stage,
                overrides: HudOverrides(link: nil, frame: stage.theme.frame, label: nil, message: nil), decoding: nil)
            switch Choreography.exitStyle(motion) {
            case .drop:
                TransitionEffect.drop(
                    &grid, leaving: old, stage: stage, moment: Moment(elapsed: motion.article, seed: motion.seed))
            case .scan:
                TransitionEffect.scan(&grid, leaving: old, stage: stage, elapsed: motion.article)
            }
        } else {
            stage.body.clear(&grid)
            TransitionEffect.trace(&grid, stage: stage, elapsed: motion.article)
        }
    }

    /// いつも出ている動き（HUD の呼吸）。
    static func animateHud(_ grid: inout Grid, state: StripState, stage: Stage, entry: Int?) {
        let motion = state.motion
        AmbientEffect.sweep(&grid, stage: stage, global: motion.global)
        let feeds = min(state.feeds.count, bodyRows)
        guard state.article != nil else {
            BootView.hexStream(&grid, stage: stage, feeds: feeds, global: motion.global)
            return
        }
        AmbientEffect.dataWindow(&grid, stage: stage, state: state)
        guard let entry, entry >= Choreography.entry else {
            return
        }
        AmbientEffect.blink(&grid, stage: stage, global: motion.global)
        if !state.paused {
            AmbientEffect.fuse(
                &grid, stage: stage, remaining: 1 - Double(motion.article) / Double(max(motion.interval, 1)))
        }
    }
}
