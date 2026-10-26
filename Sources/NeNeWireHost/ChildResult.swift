/// 終わった子プロセスの終わり方と出力。
public struct ChildResult: Sendable, Hashable {
    public let termination: ChildTermination
    /// 標準出力のバイト列。
    public let output: [UInt8]
    /// 標準エラーのバイト列。
    public let errorOutput: [UInt8]
}
