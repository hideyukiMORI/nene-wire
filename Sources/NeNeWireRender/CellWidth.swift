/// 文字が端末で占める桁数（FR-04）。幅を数えるのはここ 1 か所（ADR 0006）。
public enum CellWidth {
    /// 1 文字（書記素クラスタ）の桁数。結合文字や書式文字だけなら 0、全角（W・F）か絵文字の表示を求める異体字セレクタ付きなら 2、それ以外は 1。
    public static func of(_ character: Character) -> Int {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else {
            return 0
        }
        if isZeroWidth(first) {
            return 0
        }
        if isWide(first.value) || scalars.contains(where: { $0.value == 0xFE0F }) {
            return 2
        }
        return 1
    }

    /// 文字列の桁数。
    public static func of(_ text: String) -> Int {
        text.reduce(0) { total, character in total + of(character) }
    }

    /// 符号位置が全角か（表を二分探索する）。
    static func isWide(_ value: UInt32) -> Bool {
        var low = 0
        var high = EastAsianWidth.wide.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let range = EastAsianWidth.wide[middle]
            if value < range.lowerBound {
                high = middle - 1
            } else if value > range.upperBound {
                low = middle + 1
            } else {
                return true
            }
        }
        return false
    }

    /// 幅を持たない一般カテゴリ（結合文字・囲み記号・書式文字・制御文字）。
    /// `Unicode.GeneralCategory` は凍結されていない enum で、`switch` には全捕捉が要る（CNF-013 が拒む）ので、集合で引く。
    private static let zeroWidthCategories: Set<Unicode.GeneralCategory> = [
        .nonspacingMark, .enclosingMark, .format, .control,
    ]

    private static func isZeroWidth(_ scalar: Unicode.Scalar) -> Bool {
        zeroWidthCategories.contains(scalar.properties.generalCategory)
    }
}
