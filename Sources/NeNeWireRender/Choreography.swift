/// 1 件の記事の演出の時刻割り（ADR 0009）。どの時刻に何が起きるかを決めるのはここ 1 か所。
///
/// 記事を見せ始めると、まず「前置き」（速報なら緊急傍受の警告・前の記事があれば切り替え・最初の記事なら枠を描く）、
/// 続いて「確定」（くるくる確定と復号中の表示）、そのあと静止し、静止中に 2 回だけ電脳ノイズが走る。
enum Choreography {
    /// 切り替え（前の記事が落ちる・走査線で消える）の長さ。
    static let transition = 900
    /// 速報の警告の長さ。
    static let alarm = 1_600
    /// 最初の記事の前に枠をなぞって描く長さ。
    static let trace = 800
    /// くるくる確定がすべて止まるまでの長さ（どの止まり方もこの中に収める）。
    static let entry = 2_600
    /// 電脳ノイズ 1 回の長さ。
    static let burst = 240

    /// 前置きの長さ。
    static func lead(fresh: Bool, motion: Motion) -> Int {
        if fresh {
            return alarm
        }
        if motion.leaving != nil {
            return transition
        }
        return motion.firstEntry ? trace : 0
    }

    /// 確定が始まってからのミリ秒。まだ前置きの中なら nil。
    static func entryElapsed(fresh: Bool, motion: Motion) -> Int? {
        let elapsed = motion.article - lead(fresh: fresh, motion: motion)
        return elapsed >= 0 ? elapsed : nil
    }

    static func spinOrder(_ motion: Motion) -> SpinOrder {
        Noise.pick(SpinOrder.allCases, motion.seed, 2)
    }

    static func exitStyle(_ motion: Motion) -> ExitStyle {
        Noise.pick(ExitStyle.allCases, motion.seed, 3)
    }

    /// 電脳ノイズが走る時刻（確定が始まってからのミリ秒）。静止の前半と後半に 1 回ずつ。
    static func bursts(_ motion: Motion) -> [Int] {
        let start = entry + 1_200
        let room = max(motion.interval - start - 1_500, 1_000)
        return [
            start + Int(Noise.unit(motion.seed, 4) * Double(room / 2)),
            start + room / 2 + Int(Noise.unit(motion.seed, 5) * Double(room / 2)),
        ]
    }

    /// いま電脳ノイズの最中か。
    static func inBurst(fresh: Bool, motion: Motion) -> Bool {
        guard let elapsed = entryElapsed(fresh: fresh, motion: motion) else {
            return false
        }
        return bursts(motion).contains { (elapsed >= $0) && (elapsed < $0 + burst) }
    }

    /// 細かく描き直す必要があるか（前置き・確定・ノイズの最中）。合成ルートが描く間隔を決めるのに使う。
    static func isBusy(fresh: Bool, motion: Motion) -> Bool {
        guard let elapsed = entryElapsed(fresh: fresh, motion: motion) else {
            return true
        }
        return elapsed < entry + 200 || inBurst(fresh: fresh, motion: motion)
    }
}
