/// 子プロセスを走らせた結果。
public enum ChildOutcome: Sendable, Hashable {
    case finished(ChildResult)
    /// 起動できなかった（`posix_spawnp` の戻り値の errno。2 なら実行ファイルが見つからない）。
    case failedToStart(Int32)
}
