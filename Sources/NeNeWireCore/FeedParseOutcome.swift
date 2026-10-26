/// フィードを解析した結果。
public enum FeedParseOutcome: Sendable, Hashable {
    case parsed(FeedDocument)
    case rejected(FeedRejection)
}
