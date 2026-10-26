/// 演出の字形（`FrameStyle` ごと）。罫線を 1 桁で描けない端末では ASCII に落とす（ADR 0009）。
struct FxGlyphs: Sendable, Hashable {
    /// 警告の縞（交互に並べる 2 つ）。
    let hazard: [String]
    /// ノイズの塊（濃い順）。
    let noise: [String]
    /// 走査線。
    let scan: String
    /// 見出しの行を走る光（先頭・中・尾）。
    let sweep: [String]
    /// 進み具合の棒（埋まった・空き）。
    let barFull: String
    let barEmpty: String
    /// 次の記事までの残り（枠の下辺の導火線）。
    let fuse: String
    /// 同期を待つ回転。
    let spinner: [String]

    /// くるくるの間に出す全角の記号（カタカナ）。
    static let wideSpin = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン")
    /// くるくるの間に出す半角の記号。
    static let narrowSpin = Array("0123456789ABCDEF#$%&*+=<>/|")
    /// 文字の雨（半角カナと 16 進）。
    static let rain = Array("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ0123456789ABCDEF")

    static func of(_ style: FrameStyle) -> FxGlyphs {
        switch style {
        case .boxDrawing:
            return FxGlyphs(
                hazard: ["▚", "▞"], noise: ["█", "▓", "▒", "░"], scan: "━", sweep: ["█", "▓", "░"], barFull: "▮",
                barEmpty: "▯", fuse: "━", spinner: ["◜", "◝", "◞", "◟"])
        case .ascii:
            return FxGlyphs(
                hazard: ["/", "\\"], noise: ["#", "%", "=", "-"], scan: "=", sweep: ["#", "=", "-"], barFull: "#",
                barEmpty: "-", fuse: "=", spinner: ["|", "/", "-", "\\"])
        }
    }
}
