/// ファイルを読んだ結果。
public enum FileRead: Sendable, Hashable {
    case text(String)
    /// ファイルが無い。
    case missing
    /// 読めなかった（errno）。
    case failed(Int32)
}
