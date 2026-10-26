/// 桁数に合わせた折り返しと切り詰め（FR-04）。折り返すのはここ 1 か所（ADR 0006）。
enum TextLayout {
    /// 行頭に置かない約物（前の 1 文字を連れて次の行へ送る）。
    private static let noLineStart: Set<Character> = [
        "、", "。", "，", "．", "）", "」", "』", "】", "！", "？", ",", ".", ")", "!", "?",
    ]

    /// `width` 桁に収まるよう折り返す。欧文は空白で切り、空白の無い長い語と和文は文字で切る。行頭の空白は捨てる。
    static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else {
            return []
        }
        var lines: [String] = []
        var line: [Character] = []
        var used = 0
        for character in text {
            let cells = CellWidth.of(character)
            if line.isEmpty, character == " " {
                continue
            }
            if used + cells <= width {
                line.append(character)
                used += cells
                continue
            }
            var (head, tail) = split(line, before: character)
            if tail.isEmpty, noLineStart.contains(character), head.count > 1, let last = head.popLast() {
                tail = [last]
            }
            lines.append(String(head))
            line = Array(tail.drop { $0 == " " })
            if character != " " || !line.isEmpty {
                line.append(character)
            }
            used = CellWidth.of(String(line))
            while used > width {
                let (fitting, rest) = cut(line, width: width)
                lines.append(String(fitting))
                line = rest
                used = CellWidth.of(String(line))
            }
        }
        if !line.isEmpty {
            lines.append(String(line))
        }
        return lines
    }

    /// `width` 桁に収め、はみ出すなら末尾を `…` にする。
    static func fit(_ text: String, width: Int) -> String {
        guard CellWidth.of(text) > width else {
            return text
        }
        guard width > 0 else {
            return ""
        }
        let (fitting, _) = cut(Array(text), width: width - 1)
        return String(fitting) + "…"
    }

    /// 欧文の語の途中で切らないよう、最後の空白で分ける。空白が無いか和文に続くなら分けない。
    private static func split(_ line: [Character], before next: Character) -> ([Character], [Character]) {
        guard next != " ", CellWidth.of(next) == 1, let space = line.lastIndex(of: " "), space > 0,
            line[(space + 1)...].allSatisfy({ CellWidth.of($0) == 1 })
        else {
            return (line, [])
        }
        return (Array(line[..<space]), Array(line[(space + 1)...]))
    }

    /// 先頭から `width` 桁に収まるだけ取り、残りと分ける。
    private static func cut(_ characters: [Character], width: Int) -> ([Character], [Character]) {
        var used = 0
        var index = 0
        while index < characters.count, used + CellWidth.of(characters[index]) <= width {
            used += CellWidth.of(characters[index])
            index += 1
        }
        return (Array(characters[..<index]), Array(characters[index...]))
    }
}
