/// XML の字句解析（ADR 0005）。文字列を先頭から読み、開きタグ・閉じタグ・文字列の出来事の列にする。
///
/// フィードを読むための最小限の実装で、妥当性（タグの対応・名前空間の宣言）は検査しない。壊れた入力でも止まらずに、読めたところまでを返す。
/// 処理命令（`<?xml ...?>`）・コメント・文書型宣言は読み飛ばす。CDATA の中身は文字参照を解決せずにそのまま文字列にする。
public struct MarkupScanner {
    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var events: [MarkupEvent] = []

    private init(text: String) {
        scalars = Array(text.unicodeScalars)
    }

    /// 出来事の列。
    public static func events(_ text: String) -> [MarkupEvent] {
        var scanner = MarkupScanner(text: text)
        scanner.run()
        return scanner.events
    }

    private mutating func run() {
        while index < scalars.count {
            if scalars[index] == "<" {
                readMarkup()
            } else {
                readText()
            }
        }
    }

    private mutating func readText() {
        let start = index
        while index < scalars.count, scalars[index] != "<" {
            index += 1
        }
        let raw = String(String.UnicodeScalarView(scalars[start..<index]))
        events.append(.text(CharacterReferences.decode(raw)))
    }

    private mutating func readMarkup() {
        if starts(with: "<![CDATA[") {
            let body = take(from: index + 9, until: "]]>")
            events.append(.text(body))
        } else if starts(with: "<!--") {
            _ = take(from: index + 4, until: "-->")
        } else if starts(with: "<?") {
            _ = take(from: index + 2, until: "?>")
        } else if starts(with: "<!") {
            _ = take(from: index + 2, until: ">")
        } else if starts(with: "</") {
            let name = take(from: index + 2, until: ">").trimmingSpaces
            events.append(.close(name: name))
        } else {
            readOpenTag()
        }
    }

    private mutating func readOpenTag() {
        let body = take(from: index + 1, until: ">")
        let selfClosing = body.hasSuffix("/")
        let content = selfClosing ? String(body.dropLast()) : body
        let (name, attributes) = Self.tag(content)
        guard !name.isEmpty else {
            return
        }
        events.append(.open(name: name, attributes: attributes))
        if selfClosing {
            events.append(.close(name: name))
        }
    }

    /// `start` から区切り `terminator` の手前までの文字列。読み位置を区切りの後ろへ進める。区切りが無ければ最後まで。
    private mutating func take(from start: Int, until terminator: String) -> String {
        let marker = Array(terminator.unicodeScalars)
        var cursor = start
        while cursor < scalars.count, !matches(marker, at: cursor) {
            cursor += 1
        }
        let body = String(String.UnicodeScalarView(scalars[min(start, scalars.count)..<cursor]))
        index = min(cursor + marker.count, scalars.count)
        return body
    }

    private func starts(with prefix: String) -> Bool {
        matches(Array(prefix.unicodeScalars), at: index)
    }

    private func matches(_ marker: [Unicode.Scalar], at position: Int) -> Bool {
        guard position + marker.count <= scalars.count else {
            return false
        }
        return marker.indices.allSatisfy { scalars[position + $0] == marker[$0] }
    }

    /// タグの中身（`name a="1" b='2'`）を名前と属性に分ける。
    private static func tag(_ content: String) -> (String, [MarkupAttribute]) {
        let scalars = Array(content.unicodeScalars)
        var cursor = 0
        let name = word(in: scalars, from: &cursor)
        var attributes: [MarkupAttribute] = []
        while cursor < scalars.count {
            skipSpaces(in: scalars, from: &cursor)
            let key = word(in: scalars, from: &cursor)
            guard !key.isEmpty else {
                break
            }
            skipSpaces(in: scalars, from: &cursor)
            guard cursor < scalars.count, scalars[cursor] == "=" else {
                continue
            }
            cursor += 1
            skipSpaces(in: scalars, from: &cursor)
            attributes.append(MarkupAttribute(name: key, value: quoted(in: scalars, from: &cursor)))
        }
        return (name, attributes)
    }

    private static func word(in scalars: [Unicode.Scalar], from cursor: inout Int) -> String {
        let start = cursor
        while cursor < scalars.count, !isSpace(scalars[cursor]), scalars[cursor] != "=" {
            cursor += 1
        }
        return String(String.UnicodeScalarView(scalars[start..<cursor]))
    }

    private static func quoted(in scalars: [Unicode.Scalar], from cursor: inout Int) -> String {
        guard cursor < scalars.count, scalars[cursor] == "\"" || scalars[cursor] == "'" else {
            return word(in: scalars, from: &cursor)
        }
        let quote = scalars[cursor]
        let start = cursor + 1
        cursor = start
        while cursor < scalars.count, scalars[cursor] != quote {
            cursor += 1
        }
        let raw = String(String.UnicodeScalarView(scalars[start..<cursor]))
        cursor = min(cursor + 1, scalars.count)
        return CharacterReferences.decode(raw)
    }

    private static func skipSpaces(in scalars: [Unicode.Scalar], from cursor: inout Int) {
        while cursor < scalars.count, isSpace(scalars[cursor]) {
            cursor += 1
        }
    }

    static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\n" || scalar == "\t" || scalar == "\r"
    }
}
