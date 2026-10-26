/// 前の記事の消え方（案 A の走査線・案 F のパラパラ落ちる・ADR 0009）。記事ごとに種で選ぶ。
enum ExitStyle: Sendable, Hashable, CaseIterable {
    case drop
    case scan
}
