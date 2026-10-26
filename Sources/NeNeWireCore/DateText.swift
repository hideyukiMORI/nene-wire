/// フィードの日付の文字列を時刻にする（ADR 0005）。RSS の RFC 822（`Mon, 26 Oct 2026 01:07:05 GMT`）と、
/// Atom と RSS 1.0 の ISO 8601（`2026-10-26T10:03:19+09:00`）を読む。読めなければ nil（期待される失敗・ARC-010）。
public enum DateText {
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// どちらの形でも読む。
    public static func parse(_ text: String) -> Timestamp? {
        let trimmed = text.trimmingSpaces
        return iso8601(trimmed) ?? rfc822(trimmed)
    }

    /// `[曜日, ]日 月 年 時:分[:秒] 時差`。時差は `GMT` / `UT` / `Z` / `±hhmm`。
    static func rfc822(_ text: String) -> Timestamp? {
        let parts = text.split(separator: " ").map(String.init).filter { !$0.hasSuffix(",") }
        guard parts.count >= 4, let day = Int(parts[0]), let monthIndex = months.firstIndex(of: parts[1].lowercased()),
            var year = Int(parts[2]), let clock = clockSeconds(parts[3])
        else {
            return nil
        }
        if year < 100 {
            year += year < 70 ? 2000 : 1900
        }
        let offset = parts.count >= 5 ? zoneSeconds(parts[4]) : 0
        return offset.flatMap { zone in
            Timestamp.utc(year: year, month: monthIndex + 1, day: day, seconds: clock)?.adding(seconds: Int64(-zone))
        }
    }

    /// `YYYY-MM-DD[THH:MM[:SS[.fff]]][Z|±HH:MM]`。時刻が無ければ 0 時（UTC）。
    static func iso8601(_ text: String) -> Timestamp? {
        let chars = Array(text)
        guard chars.count >= 10, chars[4] == "-", chars[7] == "-", let year = Int(String(chars[0..<4])),
            let month = Int(String(chars[5..<7])), let day = Int(String(chars[8..<10]))
        else {
            return nil
        }
        guard chars.count > 10 else {
            return Timestamp.utc(year: year, month: month, day: day, seconds: 0)
        }
        let rest = String(chars[11...])
        let zoneStart = rest.firstIndex { $0 == "Z" || $0 == "+" || $0 == "-" } ?? rest.endIndex
        let clockText = String(rest[..<zoneStart].prefix { $0 != "." })
        guard chars[10] == "T" || chars[10] == " ", let clock = clockSeconds(clockText),
            let zone = zoneSeconds(String(rest[zoneStart...]))
        else {
            return nil
        }
        return Timestamp.utc(year: year, month: month, day: day, seconds: clock)?.adding(seconds: Int64(-zone))
    }

    /// `HH:MM[:SS]` を 0 時からの秒に。
    private static func clockSeconds(_ text: String) -> Int? {
        let parts = text.split(separator: ":").map { Int($0) }
        guard (2...3).contains(parts.count), let hour = parts[0], let minute = parts[1], (0..<24).contains(hour),
            (0..<60).contains(minute)
        else {
            return nil
        }
        let second = parts.count == 3 ? parts[2] : 0
        return second.flatMap { (0...60).contains($0) ? hour * 3600 + minute * 60 + min($0, 59) : nil }
    }

    /// 時差を秒に（東が正）。空・`Z`・`GMT`・`UT`・`UTC` は 0。
    private static func zoneSeconds(_ text: String) -> Int? {
        if text.isEmpty || ["Z", "GMT", "UT", "UTC"].contains(text.uppercased()) {
            return 0
        }
        let digits = text.dropFirst().filter { $0 != ":" }
        guard let sign = text.first, sign == "+" || sign == "-", digits.count == 4, let value = Int(digits) else {
            return nil
        }
        let seconds = (value / 100) * 3600 + (value % 100) * 60
        return sign == "-" ? -seconds : seconds
    }
}
