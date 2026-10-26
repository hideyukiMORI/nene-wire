/// キー入力から読み取った利用者の意図（閉じた集合・FR-22・ADR 0006）。
/// 移植元: NeNe Reversi `Sources/NeNeReversiTerminal/KeyIntent.swift`（コミット dc418eb）。
public enum KeyIntent: Sendable, Hashable {
    /// `q`: 終了する。
    case quit
    /// 空白: 一時停止と再開を切り替える。
    case togglePause
    /// →: 次の記事。
    case next
    /// ←: 前の記事。
    case previous
    /// `s`: 設定画面を開く（FR-22）。
    case settings

    /// 読み取ったバイト列の中の意図（順番どおり）。知らないキーとエスケープ列は捨てる。
    public static func decode(_ bytes: [UInt8]) -> [KeyIntent] {
        var intents: [KeyIntent] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x1B {
                let end = skipEscapeSequence(bytes, from: index)
                if let arrow = arrow(bytes[index..<end]) {
                    intents.append(arrow)
                }
                index = end
                continue
            }
            if byte == UInt8(ascii: "q") || byte == UInt8(ascii: "Q") {
                intents.append(.quit)
            } else if byte == UInt8(ascii: " ") {
                intents.append(.togglePause)
            } else if byte == UInt8(ascii: "s") || byte == UInt8(ascii: "S") {
                intents.append(.settings)
            }
            index += 1
        }
        return intents
    }

    /// `ESC [ C` / `ESC O C`（→）と `ESC [ D` / `ESC O D`（←）。修飾キー付き（`ESC [ 1 ; 5 C`）は使わない。
    private static func arrow(_ sequence: ArraySlice<UInt8>) -> KeyIntent? {
        let bytes = Array(sequence)
        guard bytes.count == 3, bytes[1] == UInt8(ascii: "[") || bytes[1] == UInt8(ascii: "O") else {
            return nil
        }
        if bytes[2] == UInt8(ascii: "C") {
            return .next
        }
        if bytes[2] == UInt8(ascii: "D") {
            return .previous
        }
        return nil
    }

    /// `ESC [ … 終端` を読み飛ばした次の位置（矢印キー等）。`ESC` 単独なら 1 つ進める。
    private static func skipEscapeSequence(_ bytes: [UInt8], from start: Int) -> Int {
        var index = start + 1
        guard index < bytes.count, bytes[index] == UInt8(ascii: "[") || bytes[index] == UInt8(ascii: "O") else {
            return index
        }
        index += 1
        while index < bytes.count, !(0x40...0x7E).contains(bytes[index]) {
            index += 1
        }
        return min(index + 1, bytes.count)
    }
}
