/// 起動時に端末に問い合わせて分かった性質（合成ルートが測って渡す）。
/// 移植元: NeNe Reversi `Sources/NeNeReversiRender/TerminalTraits.swift`（コミット dc418eb）。
public struct TerminalTraits: Sendable, Hashable {
    /// 枠の字形（罫線が 1 桁で描かれるときだけ罫線）。
    public let frame: FrameStyle
    /// 24 ビットか 256 色か。
    public let colors: ColorMode

    /// 組を作る。
    public init(frame: FrameStyle, colors: ColorMode) {
        self.frame = frame
        self.colors = colors
    }
}
