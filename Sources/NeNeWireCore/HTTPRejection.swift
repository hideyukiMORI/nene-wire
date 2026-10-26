/// curl の出力を HTTP の応答として読めなかった理由。
public enum HTTPRejection: Sendable, Hashable {
    /// 先頭が `HTTP/` の状態行でない（ヘッダを出す指定が無い・空の出力）。
    case noStatusLine
}
