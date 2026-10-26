/// フィードの形式。
public enum FeedFormat: Sendable, Hashable {
    case rss2
    /// RSS 1.0（RDF）。
    case rss1
    case atom
}
