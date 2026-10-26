/// フィードの 1 項目を、XML から読んだままの値で持つ（HTML の除去や出だしの切り出しは `Article` が行う）。
public struct FeedItem: Sendable, Hashable {
    public let title: String
    public let link: String
    /// 要約欄（HTML のことがある）。
    public let summary: String
    public let published: Timestamp?
    /// 記事の識別子（guid / id。無ければリンク）。
    public let identifier: String
}
