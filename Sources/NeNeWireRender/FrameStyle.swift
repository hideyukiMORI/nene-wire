/// 枠の字形の組。罫線が 1 桁で描かれる端末だけ罫線を使い、それ以外は ASCII へ落とす（ADR 0006）。
/// 移植元: NeNe Reversi `Sources/NeNeReversiRender/FrameStyle.swift`（コミット dc418eb）。
public enum FrameStyle: Sendable, Hashable {
    /// 罫線とブロック（`┌─┬│▌●`）。
    case boxDrawing
    /// ASCII（`+-|>*`）。
    case ascii
}
