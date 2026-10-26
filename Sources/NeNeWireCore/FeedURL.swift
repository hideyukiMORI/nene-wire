/// フィードの URL。`http://` か `https://` で始まり、ホスト名を持つものだけ（ARC-008: 境界で 1 度だけ検証する）。
public struct FeedURL: Sendable, Hashable {
    public let text: String
    /// ホスト名（一覧に「ドメイン程度」で出す・FR-23）。
    public let host: String

    private init(text: String, host: String) {
        self.text = text
        self.host = host
    }

    /// 文字列から作る。空白を含む・スキームが http(s) でない・ホスト名が無いなら nil。
    public static func parse(_ raw: String) -> FeedURL? {
        let text = raw.trimmingSpaces
        guard !text.unicodeScalars.contains(where: { $0.isSpace }) else {
            return nil
        }
        let lower = text.lowercased()
        let rest: Substring
        if lower.hasPrefix("https://") {
            rest = text.dropFirst(8)
        } else if lower.hasPrefix("http://") {
            rest = text.dropFirst(7)
        } else {
            return nil
        }
        let authority = rest.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        let host = String((authority.split(separator: "@").last ?? "").prefix { $0 != ":" }).lowercased()
        guard !host.isEmpty else {
            return nil
        }
        return FeedURL(text: text, host: host)
    }
}
