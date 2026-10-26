/// 演出が見出しの行・枠・メッセージの行を一時的に差し替える分（ADR 0009）。
struct HudOverrides {
    /// 見出しの行の回線の状態の代わり。
    let link: Segment?
    /// 枠の色。
    let frame: Rgb
    /// 枠の左上のラベルの代わり。
    let label: Segment?
    /// メッセージの行の代わり。
    let message: Segment?
}
