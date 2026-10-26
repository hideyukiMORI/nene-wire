/// 前回から届いたシグナル。
public struct ConsoleSignals: Sendable, Hashable {
    /// SIGINT（Ctrl+C）・SIGTERM・SIGHUP。終了する。
    public let interrupted: Bool
    /// SIGWINCH。大きさを読み直して描き直す。
    public let resized: Bool
}
