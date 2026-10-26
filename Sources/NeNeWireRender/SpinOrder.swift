/// くるくる確定の止まり方（案 A1〜A3・ADR 0009）。記事ごとに種で選ぶ。
enum SpinOrder: Sendable, Hashable, CaseIterable {
    /// 1 文字ずつ現れ、それぞれくるくるしてから止まる。
    case cascade
    /// 行ごと一斉にくるくるし、左から順に止まる。
    case sweep
    /// ばらばらの順に止まる。
    case scatter
}
