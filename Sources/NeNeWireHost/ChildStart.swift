/// 子プロセスを起動した結果。
public enum ChildStart: Sendable, Hashable {
    case running(RunningChild)
    /// 起動できなかった（`posix_spawnp` の戻り値の errno）。
    case failedToStart(Int32)
}
