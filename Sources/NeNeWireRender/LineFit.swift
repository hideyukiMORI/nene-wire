/// 1 行に並べる切れの組を、桁数に収まるまで優先度の低いものから落とす（#34）。落とす順は `dropOrder`（組の番号）。
/// 落とし切っても収まらなければ、そのまま返す（書くときに右端が切れる）。
enum LineFit {
    static func fit(_ groups: [[Segment]], dropOrder: [Int], width: Int) -> [Segment] {
        var kept = Set(groups.indices)
        func line() -> [Segment] {
            groups.indices.filter(kept.contains).flatMap { groups[$0] }
        }
        func cells() -> Int {
            line().reduce(0) { $0 + CellWidth.of($1.text) }
        }
        for index in dropOrder where cells() > width {
            kept.remove(index)
        }
        return line()
    }
}
