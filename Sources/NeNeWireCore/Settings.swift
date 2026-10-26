/// 設定（FR-23・FR-24）: フィードの一覧と表示の設定。
public struct Settings: Sendable, Hashable {
    public let feeds: [Feed]
    public let display: DisplaySettings

    /// 設定を作る。
    public init(feeds: [Feed], display: DisplaySettings) {
        self.feeds = feeds
        self.display = display
    }

    /// 初めて起動したとき（FR-26）。
    public static let defaults = Settings(feeds: Feed.defaults, display: .defaults)
}
