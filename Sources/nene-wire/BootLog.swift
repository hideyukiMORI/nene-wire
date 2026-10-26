import NeNeWireCore
import NeNeWireRender

/// 接続シーケンスのブートログ（案 D・FR-20・ADR 0009）。実際の取得の結果を 1 行ずつ足す。最後の 2 行だけは演出の決まり文句。
struct BootLog {
    private(set) var lines: [LogLine]
    private var finished = false

    init(version: String, size: ScreenSize, translator problem: TranslatorProblem?) {
        let engine =
            problem == nil
            ? "> 翻訳エンジン Argos Translate  en>ja  [ OK ]"
            : "> 翻訳エンジン  ……  未導入（install-translator.sh で入る）  原文で流す"
        lines = [
            LogLine(text: "> nene-wire \(version)  //  電脳ニュース回線", at: 0),
            LogLine(text: "> 端末を確保  \(size.columns)x\(size.rows)  [ OK ]", at: 300),
            LogLine(text: engine, at: 600),
            LogLine(text: "> 回線を確立中 …", at: 900),
        ]
    }

    /// 打ち終わる時刻（起動してからのミリ秒・1 秒に 60 文字・少し余韻を置く）。
    var typedBy: Int {
        guard let last = lines.last else {
            return 0
        }
        return last.at + last.text.count * 1_000 / 60 + 700
    }

    mutating func record(_ arrival: Fetcher.Arrival, name: String, at time: Int) {
        let at = max(time, (lines.last?.at ?? 0) + 250)
        switch arrival.outcome {
        case .fetched:
            lines.append(LogLine(text: "> 回線 \(name)  …  \(arrival.articles.count) 件  [ OK ]", at: at))
        case .notModified:
            lines.append(LogLine(text: "> 回線 \(name)  …  更新なし  [ OK ]", at: at))
        case .failed(let failure):
            lines.append(LogLine(text: "> 回線 \(name)  …  \(FeedFetch.describe(failure))  [FAIL]", at: at))
        }
    }

    /// 保存した記事を読み込んだ。
    mutating func restored(_ count: Int, at time: Int) {
        lines.append(LogLine(text: "> 保存した記事を読み込み  …  \(count) 件  [ OK ]", at: max(time, (lines.last?.at ?? 0) + 250)))
    }

    /// すべてのフィードを一度取り終えたら、締めの 2 行を足す。
    mutating func finish(at time: Int) {
        guard !finished else {
            return
        }
        finished = true
        let at = max(time, (lines.last?.at ?? 0) + 400)
        lines.append(LogLine(text: "> ゴーストの応答を確認  ……  応答なし", at: at))
        lines.append(LogLine(text: "> 全回線を掌握。流れを開始する", at: at + 900))
    }
}
