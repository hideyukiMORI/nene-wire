import Glibc

/// 端末を戻すのに要る退避値。開いた後は異常終了のシグナルハンドラからも読むので、ここ 1 か所にだけ置く。
/// 移植元: NeNe Reversi `Sources/NeNeReversiTerminal/ConsoleState.swift`（コミット dc418eb）。
struct ConsoleState {
    var saved = termios()
    var active = false
}

/// 端末の退避値の唯一の置き場。書くのは `Console.open` と `restoreTerminal` だけ。
nonisolated(unsafe) var consoleState = ConsoleState()

/// 色とカーソルを戻し、alternate screen から出る（起動前の画面に戻る・ADR 0007）。
private let restoreSequence: [UInt8] = Array("\u{1B}[0m\u{1B}[?25h\u{1B}[?1049l".utf8)

/// 端末を戻す。シグナルハンドラからも呼ぶので、メモリを確保しない呼び出し（write と tcsetattr）だけを使う。
func restoreTerminal() {
    restoreSequence.withUnsafeBufferPointer { buffer in
        _ = Glibc.write(STDOUT_FILENO, buffer.baseAddress, buffer.count)
    }
    _ = tcsetattr(STDIN_FILENO, TCSANOW, &consoleState.saved)
    consoleState.active = false
}
