/// 空白（半角の空白・改行・タブ・全角の空白・改行しない空白）の扱い。空白とみなす文字の正本はここ 1 か所。
extension String {
    /// 前後の空白を除いた文字列。
    var trimmingSpaces: String {
        let scalars = Array(unicodeScalars)
        guard let first = scalars.firstIndex(where: { !$0.isSpace }),
            let last = scalars.lastIndex(where: { !$0.isSpace })
        else {
            return ""
        }
        return String(String.UnicodeScalarView(scalars[first...last]))
    }

    /// 連続する空白を半角の空白 1 つにまとめ、前後の空白を除いた文字列。
    var collapsingSpaces: String {
        var out = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in unicodeScalars {
            if scalar.isSpace {
                pendingSpace = !out.isEmpty
            } else {
                if pendingSpace {
                    out.append(" ")
                    pendingSpace = false
                }
                out.append(scalar)
            }
        }
        return String(out)
    }
}

extension Unicode.Scalar {
    /// 空白とみなす文字か。
    var isSpace: Bool {
        MarkupScanner.isSpace(self) || value == 0x3000 || value == 0x00A0 || value == 0x2028 || value == 0x2029
    }
}
