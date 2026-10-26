import NeNeWireRender

/// 256 色の端末の色番号（16〜255）への近似。
///
/// 6×6×6 の色立方体（16〜231・各成分 0/95/135/175/215/255）と 24 段の灰色（232〜255・8〜238）から、
/// RGB の距離がいちばん近い色を選ぶ。立方体だけで丸めると、暗い色が #5f0000 等の明るい色へ飛ぶ（NeNe Gambit の Issue #9）。
/// 移植元: NeNe Reversi `Sources/NeNeReversiTerminal/Palette256.swift`（コミット dc418eb・その元は NeNe Gambit）。
public enum Palette256 {
    private static let levels: [Int] = [0, 95, 135, 175, 215, 255]

    /// いちばん近い色番号。
    public static func nearest(_ color: Rgb) -> Int {
        let target = [Int(color.red), Int(color.green), Int(color.blue)]
        let cube = target.map { value in levels.indices.min { abs(levels[$0] - value) < abs(levels[$1] - value) } ?? 0 }
        let cubeIndex = 16 + 36 * cube[0] + 6 * cube[1] + cube[2]
        let average = target.reduce(0, +) / 3
        let step = min(max((average - 8 + 5) / 10, 0), 23)
        let grayIndex = 232 + step
        return distance(target, rgb(at: cubeIndex)) <= distance(target, rgb(at: grayIndex)) ? cubeIndex : grayIndex
    }

    /// 色番号（16〜255）の RGB 成分。
    public static func rgb(at index: Int) -> [Int] {
        if index >= 232 {
            let gray = 8 + 10 * (index - 232)
            return [gray, gray, gray]
        }
        let cube = index - 16
        return [levels[cube / 36], levels[cube / 6 % 6], levels[cube % 6]]
    }

    private static func distance(_ a: [Int], _ b: [Int]) -> Int {
        zip(a, b).reduce(0) { total, pair in total + (pair.0 - pair.1) * (pair.0 - pair.1) }
    }
}
