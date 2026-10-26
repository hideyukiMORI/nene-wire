/// 演出に使う決まった揺らぎ（ADR 0009）。種と番号から [0, 1) の値を作る（SplitMix64 の混ぜ方）。
/// 乱数源ではなく純粋な関数なので、同じ種と番号なら同じ値になる。種そのものは合成ルートが読んで渡す（ARC-007）。
enum Noise {
    static func unit(_ seed: UInt64, _ first: Int, _ second: Int = 0) -> Double {
        var mixed =
            seed &+ UInt64(bitPattern: Int64(first)) &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(bitPattern: Int64(second)) &* 0xD1B5_4A32_D192_ED03
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31
        return Double(mixed >> 11) / Double(UInt64(1) << 53)
    }

    /// 列の中から 1 つ（空の列は渡さない）。
    static func pick<Element>(_ items: [Element], _ seed: UInt64, _ first: Int, _ second: Int = 0) -> Element {
        items[min(Int(unit(seed, first, second) * Double(items.count)), items.count - 1)]
    }
}
