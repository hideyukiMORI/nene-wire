/// 設定の文字列を読めなかった理由（ARC-009）。
public enum SettingsRejection: Sendable, Hashable {
    /// 1 行目が設定の見出しでない。
    case notSettings
    /// 知らない版（この版のプログラムでは読めない）。
    case unknownVersion(String)
    /// その行が読めない（1 から数えた行番号）。
    case malformed(line: Int)
}
