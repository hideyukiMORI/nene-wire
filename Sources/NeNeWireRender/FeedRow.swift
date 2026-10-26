import NeNeWireCore

/// DATA の窓の 1 行: フィードの名前と様子（FR-15・ADR 0007）。
public struct FeedRow: Sendable, Hashable {
    let name: String
    let health: FeedHealth
    /// いま取りに行っている最中か。
    let fetching: Bool

    /// 行を作る。
    public init(name: String, health: FeedHealth, fetching: Bool) {
        self.name = name
        self.health = health
        self.fetching = fetching
    }

    /// 記事を出せる状態か（取れた・更新なし）。
    var isLive: Bool {
        switch health {
        case .fetched, .unchanged:
            return true
        case .pending, .failed:
            return false
        }
    }

    /// 最後の取得に失敗したか。
    var isFailed: Bool {
        switch health {
        case .failed:
            return true
        case .pending, .fetched, .unchanged:
            return false
        }
    }
}
