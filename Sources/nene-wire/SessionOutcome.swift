import NeNeWireCore

/// 設定画面でキーを受けた結果、表示のループがすること。
enum SessionOutcome {
    /// 設定画面のまま。
    case stay
    /// 保存できた設定を反映する（設定画面のまま）。
    case apply(Settings)
    /// 保存できた設定を反映して閉じる。
    case applyAndClose(Settings)
    /// 閉じる（反映しない）。
    case close
}
