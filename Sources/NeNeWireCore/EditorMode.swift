/// 設定画面のいまの状態。
public enum EditorMode: Sendable, Hashable {
    /// 一覧と設定を見て動かしている。
    case browse
    /// フィードの名前と URL を打っている。
    case form(FeedForm)
    /// 選んだフィードを消すかを確かめている。
    case confirmDelete
    /// 保存していない変更があるまま閉じようとしている（FR-25）。
    case confirmClose
}
