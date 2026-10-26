import NeNeWireCore

/// いま見せている記事の時計と種（ADR 0009）。一時停止の間は止まる。種は記事ごとに合成ルートの乱数で決める（ARC-007）。
struct Showtime {
    private let clock = ContinuousClock()
    private var started: ContinuousClock.Instant
    private var frozen: Duration?
    private var generator = SystemRandomNumberGenerator()
    private(set) var seed: UInt64 = 0
    /// 切り替えで消えていく前の記事。
    private(set) var leaving: Article?
    /// 起動して最初の記事か。
    private(set) var firstEntry = false

    init() {
        started = clock.now
    }

    /// 次の記事を見せ始める。
    mutating func begin(leaving previous: Article?, first: Bool) {
        started = clock.now
        frozen = nil
        seed = generator.next()
        leaving = previous
        firstEntry = first
    }

    /// 見せ始めてからのミリ秒（一時停止の間は止まる）。
    var milliseconds: Int {
        Self.milliseconds(frozen ?? (clock.now - started))
    }

    mutating func pause() {
        frozen = clock.now - started
    }

    mutating func resume() {
        if let frozen {
            started = clock.now - frozen
        }
        frozen = nil
    }

    static func milliseconds(_ duration: Duration) -> Int {
        let (seconds, attoseconds) = duration.components
        return Int(seconds * 1_000 + attoseconds / 1_000_000_000_000_000)
    }
}
