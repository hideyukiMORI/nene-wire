/// 端末の大きさ（桁数と行数）。
public struct ScreenSize: Sendable, Hashable {
    public let columns: Int
    public let rows: Int

    /// 大きさを作る。負の値は 0 にする（端末が大きさを返せなかったとき）。
    public init(columns: Int, rows: Int) {
        self.columns = max(columns, 0)
        self.rows = max(rows, 0)
    }
}
