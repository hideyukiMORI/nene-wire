import Glibc

/// 走っている子プロセス。標準出力と標準エラーを読み口から少しずつ集め、両方が閉じたら終わり方を受け取る（ADR 0007）。
public struct RunningChild: Sendable, Hashable {
    private let pid: pid_t
    private var open: [Int32]
    private var collected: [[UInt8]] = [[], []]

    init(pid: pid_t, output: Int32, errorOutput: Int32) {
        self.pid = pid
        open = [output, errorOutput]
    }

    /// まだ閉じていない読み口（表示のループが `poll` で一緒に待つ）。
    public var descriptors: [Int32] {
        open.filter { $0 >= 0 }
    }

    /// 読めるだけ読む（待たない）。両方の読み口が閉じたら、子の終わりを待って結果を返す。まだなら nil。
    public mutating func pump() -> ChildResult? {
        pump(waiting: 0)
    }

    /// 読める出力が来るまで最大 `milliseconds` 待って（-1 なら来るまで）読む。
    mutating func pump(waiting milliseconds: Int32) -> ChildResult? {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        var requests = open.map { pollfd(fd: $0, events: Int16(POLLIN), revents: 0) }
        if poll(&requests, nfds_t(requests.count), milliseconds) > 0 {
            for slot in 0..<2 where open[slot] >= 0 && requests[slot].revents != 0 {
                let count = buffer.withUnsafeMutableBytes { read(open[slot], $0.baseAddress, $0.count) }
                if count > 0 {
                    collected[slot] += buffer.prefix(count)
                } else if count == 0 || errno != EINTR {
                    close(open[slot])
                    open[slot] = -1
                }
            }
        }
        guard descriptors.isEmpty else {
            return nil
        }
        return ChildResult(termination: Self.wait(for: pid), output: collected[0], errorOutput: collected[1])
    }

    /// 途中で止める（終了するとき）。SIGTERM を送り、終わりを待ち、読み口を閉じる。
    public func stop() {
        kill(pid, SIGTERM)
        _ = Self.wait(for: pid)
        for fd in descriptors {
            close(fd)
        }
    }

    private static func wait(for pid: pid_t) -> ChildTermination {
        var status: Int32 = 0
        while waitpid(pid, &status, 0) < 0, errno == EINTR {
            continue
        }
        // WIFEXITED / WEXITSTATUS / WTERMSIG のマクロは Swift から使えないので、同じビットの読み方を書く
        let signal = status & 0x7F
        return signal == 0 ? .exited((status >> 8) & 0xFF) : .signaled(signal)
    }
}
