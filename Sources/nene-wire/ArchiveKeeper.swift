import NeNeWireCore

/// いつ保存するか（ADR 0014）: 記事か訳が変わってから 30 秒に 1 回まで。終わるときは必ず。`--demo` では保存しない。
struct ArchiveKeeper {
    /// 変わってから保存するまでの最短の間隔（ミリ秒）。
    static let interval = 30_000

    private let file: ArchiveFile?
    private let clock = ContinuousClock()
    private var dirty = false
    private var lastSaved: ContinuousClock.Instant

    init(file: ArchiveFile?) {
        self.file = file
        lastSaved = clock.now
    }

    /// 記事か訳が変わった。
    mutating func touch() {
        dirty = true
    }

    /// 保存する時なら `build` で組み立てて保存する。書けなかったら理由。
    mutating func saveIfDue(force: Bool, build: () -> Archive) -> String? {
        guard let file, dirty, force || Showtime.milliseconds(clock.now - lastSaved) >= Self.interval else {
            return nil
        }
        dirty = false
        lastSaved = clock.now
        return file.save(build().pruned(at: LocalTime.timestamp()))
    }
}
