import NeNeWireCore

/// 帯に描く状態（FR-14・FR-15）。合成ルートがループの中で作る。
public struct StripState: Sendable, Hashable {
    /// 表示中の記事。手元に 1 件も無ければ nil。
    let article: Article?
    /// 表示中の記事が、取り直して新しく現れた速報か。
    let fresh: Bool
    /// 一周の中の何件目か（1 から）。
    let position: Int
    /// 一周の件数。
    let count: Int
    /// 一時停止中か。
    let paused: Bool
    /// フィードごとの様子（設定の順）。
    let feeds: [FeedRow]
    /// HUD のメッセージの行に出す 1 行（取得の進み具合など）。
    let message: String
    let clock: WallClock
    /// 演出の時計（ADR 0009）。
    let motion: Motion
    /// 最初の記事が出るまでのブートログ。
    let log: [LogLine]
    /// 割り込み待ちの速報の件数。
    let pendingFresh: Int
    /// 表示中の記事が、表示の言語と違うのに訳せていないか（「未翻訳」の印）。
    let untranslated: Bool
    /// 翻訳の様子。
    let translator: TranslatorStatus

    /// 状態を作る。
    public init(
        article: Article?, fresh: Bool, position: Int, count: Int, paused: Bool, feeds: [FeedRow], message: String,
        clock: WallClock, motion: Motion = .still, log: [LogLine] = [], pendingFresh: Int = 0,
        untranslated: Bool = false, translator: TranslatorStatus = .off
    ) {
        self.article = article
        self.fresh = fresh
        self.position = position
        self.count = count
        self.paused = paused
        self.feeds = feeds
        self.message = message
        self.clock = clock
        self.motion = motion
        self.log = log
        self.pendingFresh = pendingFresh
        self.untranslated = untranslated
        self.translator = translator
    }

    /// 記事だけを差し替えた状態（切り替えで消えていく前の記事を描くため）。
    func showing(_ other: Article) -> StripState {
        StripState(
            article: other, fresh: false, position: position, count: count, paused: paused, feeds: feeds,
            message: message, clock: clock, translator: translator)
    }

    /// 記事を出せるフィードの数。
    var feedsLive: Int {
        feeds.filter(\.isLive).count
    }
}
