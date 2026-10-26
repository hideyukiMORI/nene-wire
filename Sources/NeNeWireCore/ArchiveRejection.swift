/// 保存を読めなかった理由（ARC-009）。
public enum ArchiveRejection: Sendable, Hashable {
    /// 1 行目が保存の見出しでない。
    case notArchive
    /// 知らない版。
    case unknownVersion(String)
    /// その行が読めない（1 から数えた行番号）。
    case malformed(line: Int)
}
