/// 配色。色の値を持つのはここだけ（FR-19）。PHOSPHOR（黒地に緑の燐光・既定）・AMBER・CYAN・MAGENTA の 4 つで、設定画面で選ぶ（ADR 0011）。
/// 値はデザインのキャンバス（施主が方向性を承認・2026-10-26）から写した。警告と色ずれの色は、強調の色とぶつからないものをテーマごとに選んだ。
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

    /// テーマの一覧（設定画面の並び）。
    public static let catalog = [phosphor, amber, cyan, magenta]

    /// 名前のテーマ。知らない名前なら既定。
    public static func named(_ name: String) -> Theme {
        catalog.first { $0.name == name } ?? phosphor
    }

    static let amber = Theme(
        name: "AMBER",
        hex: [
            0x080502, 0x140C04, 0x6B4A1A, 0xFFD9A0, 0xFFF3DD, 0xFFB000, 0xB0834A, 0x5E4320, 0xFFFFFF, 0xFF5A36,
            0x3A1205,
            0x2EE6FF, 0xFF4FD8, 0x1D1205, 0x3A240A, 0x634012, 0xD08A20, 0xFFE2B0,
        ])

    static let cyan = Theme(
        name: "CYAN",
        hex: [
            0x01070B, 0x04121A, 0x1A5A74, 0xBDEAF7, 0xEEFBFF, 0x2EE6FF, 0x5B9BB0, 0x2B5568, 0xFFFFFF, 0xFFB000,
            0x3A2600,
            0xFF4FD8, 0xFFE14F, 0x031A24, 0x063346, 0x0B5A78, 0x26B8D8, 0xD2F6FF,
        ])

    static let magenta = Theme(
        name: "MAGENTA",
        hex: [
            0x08020A, 0x140518, 0x6A2A7A, 0xF3C7F7, 0xFFF0FF, 0xFF4FD8, 0xB07AB8, 0x5C3466, 0xFFFFFF, 0xFFD166,
            0x3A2E05,
            0x2EE6FF, 0x3DFF7F, 0x1C0620, 0x370C40, 0x5E1A6C, 0xD04AD0, 0xFFD6FB,
        ])

    /// 既定のテーマ。
    public static let phosphor = Theme(
        name: "PHOSPHOR",
        hex: [
            0x020805, 0x06140C, 0x1F6B40, 0xB9F2CC, 0xEAFFF1, 0x3DFF7F, 0x5A9C72, 0x2E5C40, 0xFFFFFF, 0xFFB000,
            0x3A2600,
            0x2EE6FF, 0xFF4FD8, 0x06200F, 0x0B3A1D, 0x13602F, 0x2FBF63, 0xC9FFD9,
        ])
}
