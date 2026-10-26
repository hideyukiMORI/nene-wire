import Glibc
import NeNeWireRender

/// 現地の時計（ARC-007: 時計を読むのは合成ルートだけ）。
enum LocalTime {
    /// いまの現地の日時。
    static func now() -> WallClock {
        var seconds = time(nil)
        var parts = tm()
        localtime_r(&seconds, &parts)
        let zone = parts.tm_zone.map { String(cString: $0) } ?? ""
        return WallClock(
            year: Int(parts.tm_year) + 1900, month: Int(parts.tm_mon) + 1, day: Int(parts.tm_mday),
            hour: Int(parts.tm_hour), minute: Int(parts.tm_min), second: Int(parts.tm_sec), zone: zone)
    }

    /// 次の秒の変わり目までのミリ秒（時計の表示を秒の頭で描き直すため）。
    static func millisecondsToNextSecond() -> Int32 {
        var spec = timespec()
        clock_gettime(CLOCK_REALTIME, &spec)
        return Int32(1000 - spec.tv_nsec / 1_000_000)
    }
}
