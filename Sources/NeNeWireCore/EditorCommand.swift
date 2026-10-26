/// 設定画面が合成ルートに頼むこと。
public enum EditorCommand: Sendable, Hashable {
    case none
    /// この設定を保存して反映する。
    case save(Settings)
    /// 保存して閉じる。
    case saveAndClose(Settings)
    /// 閉じる（保存していない変更は捨てる）。
    case close
    /// このフィードをその場で取って試す。
    case test(Feed)
}
