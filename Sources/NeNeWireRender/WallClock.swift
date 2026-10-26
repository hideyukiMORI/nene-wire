/// 画面に出す現地の日時（合成ルートが時計を読んで渡す・ARC-007）。
public struct WallClock: Sendable, Hashable {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let second: Int
    /// 時間帯の略称（`JST`）。
    let zone: String

    /// 日時を作る。値の範囲は時計の側が保証する。
    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, zone: String) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.zone = zone
    }

    /// `21:47:03`
    public var time: String {
        "\(Self.two(hour)):\(Self.two(minute)):\(Self.two(second))"
    }

    /// `2026-10-26 21:47:03 JST`
    var stamp: String {
        "\(year)-\(Self.two(month))-\(Self.two(day)) \(time) \(zone)"
    }

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
