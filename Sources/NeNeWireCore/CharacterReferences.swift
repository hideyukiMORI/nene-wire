/// 文字参照（`&amp;`・`&#39;`・`&#x2019;` など）の解決（ADR 0005）。
///
/// XML の 5 つと、フィードの要約欄の HTML によく出る名前だけを解決する。知らない名前はそのまま残す（文字を捨てない）。
public enum CharacterReferences {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "hellip": "\u{2026}", "mdash": "\u{2014}", "ndash": "\u{2013}", "lsquo": "\u{2018}", "rsquo": "\u{2019}",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}", "copy": "\u{00A9}", "reg": "\u{00AE}", "yen": "\u{00A5}",
        "euro": "\u{20AC}", "pound": "\u{00A3}", "middot": "\u{00B7}", "bull": "\u{2022}", "laquo": "\u{00AB}",
        "raquo": "\u{00BB}",
    ]

    /// 文字参照を解決した文字列。
    public static func decode(_ text: String) -> String {
        guard text.contains("&") else {
            return text
        }
        let scalars = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            if scalars[index] == "&", let (replacement, length) = reference(in: scalars, at: index) {
                out.append(contentsOf: replacement.unicodeScalars)
                index += length
            } else {
                out.append(scalars[index])
                index += 1
            }
        }
        return String(out)
    }

    /// `&` から始まる参照の置き換えと、参照の長さ（`;` まで）。参照でなければ nil。
    private static func reference(in scalars: [Unicode.Scalar], at start: Int) -> (String, Int)? {
        let limit = min(scalars.count, start + 12)
        guard let end = (start + 1..<limit).first(where: { scalars[$0] == ";" }), end > start + 1 else {
            return nil
        }
        let body = String(String.UnicodeScalarView(scalars[(start + 1)..<end]))
        guard let replacement = resolve(body) else {
            return nil
        }
        return (replacement, end - start + 1)
    }

    private static func resolve(_ body: String) -> String? {
        if let value = named[body] {
            return value
        }
        guard body.first == "#" else {
            return nil
        }
        let digits = body.dropFirst()
        let isHex = digits.first == "x" || digits.first == "X"
        let number = isHex ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits, radix: 10)
        return number.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }
}
