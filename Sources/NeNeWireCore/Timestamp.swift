/// 時刻（1970-01-01T00:00:00Z からの秒・UTC）。いまの時刻は合成ルートが読んで渡す（ARC-007）。
public struct Timestamp: Sendable, Hashable, Comparable {
    /// 暦の日付（UTC）。
    private struct CivilDate {
        let year: Int
        let month: Int
        let day: Int
    }

    public let seconds: Int64

    private init(seconds: Int64) {
        self.seconds = seconds
    }

    /// 秒から作る。
    public static func since1970(_ seconds: Int64) -> Timestamp {
        Timestamp(seconds: seconds)
    }

    /// 暦の日付と時刻（UTC）から作る。範囲の外なら nil。
    static func utc(year: Int, month: Int, day: Int, seconds: Int) -> Timestamp? {
        guard (1970...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
            (0..<86_400).contains(seconds)
        else {
            return nil
        }
        return Timestamp(seconds: Int64(daysSince1970(year: year, month: month, day: day)) * 86_400 + Int64(seconds))
    }

    /// 時刻を秒だけずらした時刻。
    public func adding(seconds delta: Int64) -> Timestamp {
        Timestamp(seconds: seconds + delta)
    }

    /// ISO 8601 の UTC の文字列（`2026-10-26T03:16:15Z`）。時刻を文字にする正本の形。
    public var iso8601: String {
        let days = Int(seconds >= 0 ? seconds / 86_400 : (seconds - 86_399) / 86_400)
        let rest = Int(seconds - Int64(days) * 86_400)
        let date = Self.civil(daysSince1970: days)
        func two(_ value: Int) -> String {
            value < 10 ? "0\(value)" : "\(value)"
        }
        return
            "\(date.year)-\(two(date.month))-\(two(date.day))T\(two(rest / 3600)):\(two(rest / 60 % 60)):\(two(rest % 60))Z"
    }

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.seconds < rhs.seconds
    }

    /// 1970-01-01 からの日数を暦の日付に（Howard Hinnant の civil_from_days の式）。
    private static func civil(daysSince1970 days: Int) -> CivilDate {
        let shifted = days + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        return CivilDate(year: yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month: month, day: day)
    }

    /// 1970-01-01 からの日数（先発グレゴリオ暦・Howard Hinnant の days_from_civil の式）。
    private static func daysSince1970(year: Int, month: Int, day: Int) -> Int {
        let shifted = month <= 2 ? year - 1 : year
        let era = shifted / 400
        let yearOfEra = shifted - era * 400
        let monthIndex = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * monthIndex + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
