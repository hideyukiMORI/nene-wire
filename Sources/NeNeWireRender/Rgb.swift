/// 移植元: NeNe Reversi `Sources/NeNeReversiRender/Rgb.swift`（コミット dc418eb）。
/// 24 ビットの色。画面の色の値を決めるのは `Theme` だけ（Render の配色表）。
public struct Rgb: Sendable, Hashable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    /// 色を作る。どの組み合わせも正しい色なので検証は要らない（256 色への近似を Terminal とそのテストで扱うために公開する）。
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
