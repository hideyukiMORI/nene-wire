/// フィードを読めなかった理由。
public enum FeedRejection: Sendable, Hashable {
    /// 根の要素が `rss` / `rdf:RDF` / `feed` のどれでもない（HTML のページなど）。
    case notFeed
    /// XML 宣言の文字コードが UTF-8 でない（UTF-8 だけを読む）。
    case unsupportedEncoding(String)
}
