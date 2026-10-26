/// 解析したフィード。
public struct FeedDocument: Sendable, Hashable {
    public let title: String
    public let format: FeedFormat
    public let items: [FeedItem]
}
