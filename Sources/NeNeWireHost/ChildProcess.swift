import Glibc

/// 子プロセスを起動し、終わるまで標準出力と標準エラーを受け取る（ADR 0004・ADR 0005）。外部プロセスを起動する経路はここ 1 つ（CNF-023）。
///
/// 標準入力は `/dev/null`。2 つのパイプを `poll(2)` で読むので、片方が詰まって子プロセスが止まることはない。
/// 子プロセスは親のシグナルのマスクと「無視」の設定を受け継ぐので、マスクを空にし、終了に関わるシグナルを既定の動作に戻して起動する
/// （親が SIGTERM を塞いでいると、子を止められなくなる。テストの実行環境で実際に起きた）。
/// 環境変数はこの区画で読まず、呼ぶ側（合成ルート）が `NAME=value` の列で渡す（ARC-007）。
public enum ChildProcess {
    /// 子プロセスを走らせ、終わるまで待つ。
    public static func run(_ command: ChildCommand) -> ChildOutcome {
        switch start(command) {
        case .failedToStart(let code):
            return .failedToStart(code)
        case .running(var child):
            while true {
                if let result = child.pump(waiting: -1) {
                    return .finished(result)
                }
            }
        }
    }

    /// 子プロセスを起動して、待たずに返す（表示のループが、キー入力と一緒に出力を待つため・ADR 0007）。
    public static func start(_ command: ChildCommand) -> ChildStart {
        var output: [Int32] = [-1, -1]
        var errorOutput: [Int32] = [-1, -1]
        guard pipe(&output) == 0 else {
            return .failedToStart(errno)
        }
        guard pipe(&errorOutput) == 0 else {
            closeAll(output)
            return .failedToStart(errno)
        }
        let started = spawn(command, output: output, errorOutput: errorOutput)
        close(output[1])
        close(errorOutput[1])
        guard case .success(let pid) = started else {
            closeAll([output[0], errorOutput[0]])
            return .failedToStart(started.failure)
        }
        return .running(RunningChild(pid: pid, output: output[0], errorOutput: errorOutput[0]))
    }

    private enum Spawned {
        case success(pid_t)
        case failure(Int32)

        var failure: Int32 {
            switch self {
            case .success:
                return 0
            case .failure(let code):
                return code
            }
        }
    }

    private static func spawn(_ command: ChildCommand, output: [Int32], errorOutput: [Int32]) -> Spawned {
        var actions = posix_spawn_file_actions_t()
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, output[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errorOutput[1], 2)
        for fd in output + errorOutput {
            posix_spawn_file_actions_addclose(&actions, fd)
        }
        let argv = cStrings([command.executable] + command.arguments)
        let envp = cStrings(command.environment)
        defer {
            for pointer in argv + envp {
                free(pointer)
            }
        }
        var attributes = posix_spawnattr_t()
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        var unblocked = sigset_t()
        sigemptyset(&unblocked)
        posix_spawnattr_setsigmask(&attributes, &unblocked)
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in [SIGTERM, SIGINT, SIGHUP, SIGQUIT, SIGPIPE] {
            sigaddset(&defaults, signal)
        }
        posix_spawnattr_setsigdefault(&attributes, &defaults)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
        var pid: pid_t = 0
        let status = posix_spawnp(&pid, command.executable, &actions, &attributes, argv, envp)
        return status == 0 ? .success(pid) : .failure(status)
    }

    /// C の文字列の配列（最後は nil）。呼んだ側が `free` する。
    private static func cStrings(_ values: [String]) -> [UnsafeMutablePointer<CChar>?] {
        values.map { strdup($0) } + [nil]
    }

    private static func closeAll(_ descriptors: [Int32]) {
        for fd in descriptors where fd >= 0 {
            close(fd)
        }
    }
}
