/// 配色。色の値を持つのはここだけ。いまは既定の PHOSPHOR（黒地に緑の燐光・FR-19）の 1 つで、ほかのテーマは設定画面の段で足す。
/// 値はデザインのキャンバス（施主が方向性を承認・2026-10-26）から写した。
/// 読ませる文字（本文・見出し・強調・控えめ）は地と帯に対して 4.5:1 以上（テストで確かめる）。`faint` は飾りの線と札だけに使う。
public struct Theme: Sendable, Hashable {
    public let name: String
    let ground: Rgb
    let panel: Rgb
    let frame: Rgb
    let text: Rgb
    let head: Rgb
    let accent: Rgb
    let dim: Rgb
    let faint: Rgb
    /// 演出の光（確定の瞬間・走査線の芯）。
    let flash: Rgb
    /// 警告（速報の割り込み）とその暗い地。
    let warn: Rgb
    let warnDeep: Rgb
    /// 電脳ノイズの色ずれ（2 色）。
    let split: [Rgb]
    /// 文字の雨（暗い順に 5 段）。
    let rain: [Rgb]

    private init(name: String, hex: [UInt32]) {
        precondition(hex.count == 18, "テーマの色は 18（基本 8・光・警告 2・色ずれ 2・雨 5）")
        func rgb(_ value: UInt32) -> Rgb {
            Rgb(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
        }
        self.name = name
        ground = rgb(hex[0])
        panel = rgb(hex[1])
        frame = rgb(hex[2])
        text = rgb(hex[3])
        head = rgb(hex[4])
        accent = rgb(hex[5])
        dim = rgb(hex[6])
        faint = rgb(hex[7])
        flash = rgb(hex[8])
        warn = rgb(hex[9])
        warnDeep = rgb(hex[10])
        split = [rgb(hex[11]), rgb(hex[12])]
        rain = hex[13...17].map(rgb)
    }

    /// 既定のテーマ。
    public static let phosphor = Theme(
        name: "PHOSPHOR",
        hex: [
            0x020805, 0x06140C, 0x1F6B40, 0xB9F2CC, 0xEAFFF1, 0x3DFF7F, 0x5A9C72, 0x2E5C40, 0xFFFFFF, 0xFFB000,
            0x3A2600,
            0x2EE6FF, 0xFF4FD8, 0x06200F, 0x0B3A1D, 0x13602F, 0x2FBF63, 0xC9FFD9,
        ])
}
