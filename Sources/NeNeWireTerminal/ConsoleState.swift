import Glibc

/// 端末を戻すのに要る退避値。開いた後は異常終了のシグナルハンドラからも読むので、ここ 1 か所にだけ置く。
/// 移植元: NeNe Reversi `Sources/NeNeReversiTerminal/ConsoleState.swift`（コミット dc418eb）。
struct ConsoleState {
    var saved = termios()
    var active = false
}

/// 端末の退避値の唯一の置き場。書くのは `Console.open` と `restoreTerminal` だけ。
nonisolated(unsafe) var consoleState = ConsoleState()

/// 帯の左上（`ESC 7` で覚えた位置）へ戻り、そこから下を消し、色とカーソルを戻す。帯の上にあったシェルの履歴は残る（ADR 0006）。
private let restoreSequence: [UInt8] = Array("\u{1B}8\u{1B}[0m\u{1B}[J\u{1B}[?25h".utf8)

/// 端末を戻す。シグナルハンドラからも呼ぶので、メモリを確保しない呼び出し（write と tcsetattr）だけを使う。
func restoreTerminal() {
    restoreSequence.withUnsafeBufferPointer { buffer in
        _ = Glibc.write(STDOUT_FILENO, buffer.baseAddress, buffer.count)
    }
    _ = tcsetattr(STDIN_FILENO, TCSANOW, &consoleState.saved)
    consoleState.active = false
}
