/// 表示する記事の巡り（FR-12・ADR 0007）。フィードごとの最新の記事を持ち、一周したら最新の内容で並べ直す。
/// 取り直して新しく現れた記事は「速報」として、次の 1 件に割り込ませる。
///
/// 持つ記事はフィードごとに最後に取れた分だけなので、一晩流しても増え続けない（FR-02）。
public struct Rotation: Sendable, Hashable {
    /// 割り込み待ちの速報の上限（取り直しで一度に大量に来ても、古いものから捨てる）。
    static let freshLimit = 20

    private var pools: [[Article]]
    /// 一度でも取れたフィード（そのフィードの初回の記事は速報にしない）。
    private var received: Set<Int> = []
    private var order: [Article] = []
    private var index = 0
    private var fresh: [Article] = []
    private var showing: Article?
    private var showingFresh = false

    private init(feeds: Int) {
        pools = Array(repeating: [], count: feeds)
    }

    /// まだ何も取っていない巡り。
    public static func empty(feeds: Int) -> Rotation {
        Rotation(feeds: feeds)
    }

    /// いま見せている記事。
    public var current: Article? {
        showing
    }

    /// いま見せている記事が割り込んだ速報か。
    public var isFresh: Bool {
        showingFresh
    }

    /// 一周の中の何件目か（1 から・何も無ければ 0）。
    public var position: Int {
        order.isEmpty ? 0 : index + 1
    }

    /// 割り込み待ちの速報の件数。
    public var pendingFresh: Int {
        fresh.count
    }

    /// いま持っている記事（フィードの順・割り込み待ちの速報を含む）。
    public var articles: [Article] {
        pools.flatMap { $0 } + fresh
    }

    /// いま持っている記事の識別子（一周と、割り込み待ちの速報）。
    public var identifiers: Set<String> {
        Set(pools.flatMap { $0.map(\.identifier) } + fresh.map(\.identifier))
    }

    /// 一周の件数。
    public var count: Int {
        order.count
    }

    /// `feed` 番目のフィードの記事を、取れた最新の内容で置き換える。そのフィードを前にも取れていたなら、新しく現れた記事を速報にする。
    /// 何も見せていなかったなら、すぐに一周を組んで最初の記事を見せる。初めて取れたフィードは、いまの一周の残りに混ぜる（起動直後の一周が最初のフィードだけにならない）。
    public mutating func replace(feed: Int, with articles: [Article]) {
        guard pools.indices.contains(feed) else {
            return
        }
        if received.contains(feed) {
            let known = Set(pools[feed].map(\.identifier))
            let arrivals = Lineup.interleaved([articles.filter { !known.contains($0.identifier) }])
            fresh = Array((arrivals + fresh).prefix(Self.freshLimit))
        }
        let firstTime = !received.contains(feed)
        pools[feed] = articles
        received.insert(feed)
        if showing == nil {
            rebuild()
        } else if firstTime {
            mergeIntoRemainder()
        }
    }

    /// 次の記事へ。速報があればそれを先に見せる。一周したら最新の内容で並べ直す。
    public mutating func advance() {
        if !fresh.isEmpty {
            showing = fresh.removeFirst()
            showingFresh = true
            return
        }
        if index + 1 < order.count {
            index += 1
            showing = order[index]
            showingFresh = false
        } else {
            rebuild()
        }
    }

    /// 前の記事へ（一周の中で。最初の前は最後）。
    public mutating func goBack() {
        guard !order.isEmpty else {
            return
        }
        index = (index - 1 + order.count) % order.count
        showing = order[index]
        showingFresh = false
    }

    /// いまの一周の、まだ見せていない残りを、すべてのフィードの記事で組み直す。
    private mutating func mergeIntoRemainder() {
        let done = Array(order.prefix(index + 1))
        let shown = Set(done.map(\.identifier))
        order = done + Lineup.interleaved(pools).filter { !shown.contains($0.identifier) }
    }

    private mutating func rebuild() {
        order = Lineup.interleaved(pools)
        index = 0
        showing = order.first
        showingFresh = false
    }
}
