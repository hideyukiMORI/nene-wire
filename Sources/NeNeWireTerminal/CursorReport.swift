/// 移植元: NeNe Reversi `Sources/NeNeReversiTerminal/CursorReport.swift`（コミット dc418eb・その元は NeNe Gambit）。
/// 端末のカーソル位置の報告（`ESC [ 行 ; 桁 R`）を読む。
public enum CursorReport {
    /// バイト列の中の最後の報告の桁（1 から）。報告が無ければ nil。
    public static func column(in bytes: [UInt8]) -> Int? {
        guard let end = bytes.lastIndex(of: UInt8(ascii: "R")),
            let start = bytes[..<end].lastIndex(of: 0x1B),
            start + 1 < end, bytes[start + 1] == UInt8(ascii: "[")
        else {
            return nil
        }
        let body = String(decoding: bytes[(start + 2)..<end], as: UTF8.self)
        let parts = body.split(separator: ";")
        guard parts.count == 2, Int(parts[0]) != nil else {
            return nil
        }
        return Int(parts[1])
    }
}
