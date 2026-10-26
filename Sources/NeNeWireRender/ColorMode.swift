/// 端末に色を伝える方式。24 ビットが無ければ 256 色へ落とす。
///
/// どちらで描くかは合成ルートが端末の環境から決め、Terminal はこの値で色を符号化する。
public enum ColorMode: Sendable, Hashable {
    case trueColor
    case palette256
}
