/// 演出が描く舞台: 割り付け・演出の字形・配色の組（ADR 0009）。
struct Stage {
    let layout: StripLayout
    let fx: FxGlyphs

    var theme: Theme {
        layout.theme
    }

    var inner: Int {
        layout.inner
    }

    var body: BodyCanvas {
        BodyCanvas(inner: layout.inner, theme: layout.theme)
    }
}
