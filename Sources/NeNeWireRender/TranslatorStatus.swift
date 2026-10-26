/// 翻訳の様子（状態の行に出す・FR-15・ADR 0010）。
public enum TranslatorStatus: Sendable, Hashable {
    /// 翻訳の手段が使えない（未導入・モデルが無い）。原文のまま出している。
    case off
    /// 使える。`route` は `en>ja` の形（矢印は端末によって 2 桁に描かれるので使わない）、`pending` は訳を待っている件数、`busy` はいま訳している最中か。
    case ready(route: String, pending: Int, busy: Bool)
}
