/// 走らせる子プロセス: 実行ファイル（`PATH` から探す）・引数・環境変数（`NAME=value` の列）。
public struct ChildCommand: Sendable, Hashable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String]

    /// 組を作る。環境変数は呼ぶ側（合成ルート）が読んで渡す（ARC-007）。
    public init(executable: String, arguments: [String], environment: [String]) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }
}
