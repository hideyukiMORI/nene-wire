/// 翻訳の手段を 1 回呼んだ結果。
public enum TranslationOutcome: Sendable, Hashable {
    /// 渡した順の訳。
    case translated([String])
    case unavailable(TranslatorProblem)
}
