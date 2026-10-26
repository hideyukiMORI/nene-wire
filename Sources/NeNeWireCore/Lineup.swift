/// 表示の並べ方（FR-12）。フィードを順番に巡回しながら、それぞれ新しい記事から 1 件ずつ取る。並べるのはここ 1 か所。
public enum Lineup {
    /// フィードごとの記事の列（フィードの順）から、表示の順を作る。
    /// 各フィードの中は公開時刻の新しい順（時刻の無い記事は後ろ・同じなら元の順）。同じ識別子の記事は最初の 1 件だけ残す。
    public static func interleaved(_ groups: [[Article]]) -> [Article] {
        let sorted = groups.map(newestFirst)
        var seen: Set<String> = []
        var order: [Article] = []
        let depth = sorted.map(\.count).max() ?? 0
        for index in 0..<depth {
            for group in sorted where index < group.count {
                let article = group[index]
                if seen.insert(article.identifier).inserted {
                    order.append(article)
                }
            }
        }
        return order
    }

    private static func newestFirst(_ articles: [Article]) -> [Article] {
        articles.enumerated().sorted { lhs, rhs in
            switch (lhs.element.published, rhs.element.published) {
            case (.some(let left), .some(let right)) where left != right:
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.some, .some), (.none, .none):
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }
}
