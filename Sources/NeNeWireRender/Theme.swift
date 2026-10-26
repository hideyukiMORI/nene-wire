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

    private init(name: String, hex: [UInt32]) {
        precondition(hex.count == 8, "テーマの色は 8 つ")
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
    }

    /// 既定のテーマ。
    public static let phosphor = Theme(
        name: "PHOSPHOR", hex: [0x020805, 0x06140C, 0x1F6B40, 0xB9F2CC, 0xEAFFF1, 0x3DFF7F, 0x5A9C72, 0x2E5C40])
}
