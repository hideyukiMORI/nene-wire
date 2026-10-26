/// ファイルに書いた結果。
public enum FileWrite: Sendable, Hashable {
    case written
    /// 書けなかった（errno）。
    case failed(Int32)
}
