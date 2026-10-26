/// 翻訳の手段が使えない理由（FR-29）。
public enum TranslatorProblem: Sendable, Hashable {
    /// 翻訳の手段が入っていない（置き場が無い・Python が読み込めない）。
    case notInstalled
    /// その言語の組のモデルが入っていない。
    case missingModel
    /// 途中で終わった（終了コード。シグナルなら nil）。
    case crashed(Int32?)
}
