/// 子プロセスの終わり方。
public enum ChildTermination: Sendable, Hashable {
    /// 終了コードで終わった。
    case exited(Int32)
    /// シグナルで終わった。
    case signaled(Int32)
}
