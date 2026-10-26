/// 文字を打つ画面（設定画面）のためのキーの読み取り（FR-23・ADR 0011）。UTF-8 の文字（IME で確定した日本語を含む）・矢印・Tab・Enter・Backspace・Esc。
public enum KeyPress: Sendable, Hashable {
    case up
    case down
    case left
    case right
    case tab
    case enter
    case escape
    case backspace
    case character(Character)

    /// 読み取ったバイト列のキー（順番どおり）。知らないエスケープ列と制御文字は捨てる。
    /// `ESC` の直後に `[` か `O` が無ければ、Esc キーが単独で押されたとみなす。
    /// 読み取りの切れ目で UTF-8 の文字が途中で切れたら、その残りを `carry` に置き、次の読み取りの頭につなげる。
    public static func decode(_ input: [UInt8], carry: inout [UInt8]) -> [KeyPress] {
        let bytes = carry + input
        carry = []
        var keys: [KeyPress] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            // バイトの値で分ける。整数の `switch` には全捕捉が要り、全捕捉は CNF-013 が拒むので `if` で書く
            if byte == 0x1B {
                let (key, next) = escape(bytes, from: index)
                if let key {
                    keys.append(key)
                }
                index = next
                continue
            }
            if (0xC2...0xF4).contains(byte) {
                let length = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : 2
                guard index + length <= bytes.count else {
                    carry = Array(bytes[index...])
                    return keys
                }
                let text = String(decoding: bytes[index..<(index + length)], as: UTF8.self)
                keys += text.filter { $0 != "\u{FFFD}" }.map(KeyPress.character)
                index += length
                continue
            }
            if let key = single(byte) {
                keys.append(key)
            }
            index += 1
        }
        return keys
    }

    /// 1 バイトで決まるキー（Tab・Enter・Backspace・印字できる ASCII）。それ以外の制御文字は nil。
    private static func single(_ byte: UInt8) -> KeyPress? {
        if byte == 0x09 {
            return .tab
        }
        if byte == 0x0D || byte == 0x0A {
            return .enter
        }
        if byte == 0x7F || byte == 0x08 {
            return .backspace
        }
        return (0x20...0x7E).contains(byte) ? .character(Character(Unicode.Scalar(byte))) : nil
    }

    /// `ESC` で始まる列を読む。矢印なら矢印、`ESC` 単独なら Esc、それ以外の列は捨てる。
    private static func escape(_ bytes: [UInt8], from start: Int) -> (KeyPress?, Int) {
        let next = start + 1
        guard next < bytes.count, bytes[next] == UInt8(ascii: "[") || bytes[next] == UInt8(ascii: "O") else {
            return (.escape, next)
        }
        var end = next + 1
        while end < bytes.count, !(0x40...0x7E).contains(bytes[end]) {
            end += 1
        }
        guard end < bytes.count else {
            return (nil, bytes.count)
        }
        let arrows: [UInt8: KeyPress] = [
            UInt8(ascii: "A"): .up, UInt8(ascii: "B"): .down, UInt8(ascii: "C"): .right, UInt8(ascii: "D"): .left,
        ]
        let key = end == next + 1 ? arrows[bytes[end]] : nil
        return (key, end + 1)
    }
}
