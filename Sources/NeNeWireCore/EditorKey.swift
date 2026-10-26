/// 設定画面に届くキー（端末の読み取りから合成ルートが作る）。
public enum EditorKey: Sendable, Hashable {
    case up
    case down
    case left
    case right
    case tab
    case enter
    case escape
    case backspace
    /// 文字（空白を含む）。
    case character(Character)
}
