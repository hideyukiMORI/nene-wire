/// 保存の文字列を読んだ結果。
public enum ArchiveOutcome: Sendable, Hashable {
    case parsed(Archive)
    case rejected(ArchiveRejection)
}
