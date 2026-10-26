import Testing

@testable import NeNeWireRender
@testable import NeNeWireTerminal

/// キーの意図・差分の書き出し・カーソル位置の報告（FR-22・ADR 0006）。
struct TerminalTests {
    @Test func keysDecodeToIntentsAndUnknownSequencesAreDropped() {
        let bytes: [UInt8] = Array("q \u{1B}[C\u{1B}OD\u{1B}[1;5Cx".utf8)
        #expect(KeyIntent.decode(bytes) == [.quit, .togglePause, .next, .previous])
        #expect(KeyIntent.decode([0x1B]).isEmpty)
    }

    @Test func cursorReportReadsTheColumn() {
        #expect(CursorReport.column(in: Array("\u{1B}[12;2R".utf8)) == 2)
        #expect(CursorReport.column(in: Array("junk".utf8)) == nil)
    }

    @Test func encoderWritesOnlyChangedRowsFromTheTopOfTheScreen() {
        let first = grid("ab", "cd")
        let full = String(decoding: FrameEncoder.encode(first, previous: nil, colors: .trueColor), as: UTF8.self)
        #expect(full.hasPrefix("\u{1B}[1;1H"))
        #expect(full.contains("\u{1B}[2;1H"))
        #expect(full.hasSuffix("\u{1B}[0m"))
        let second = grid("ab", "cX")
        let diff = String(decoding: FrameEncoder.encode(second, previous: first, colors: .trueColor), as: UTF8.self)
        #expect(diff.contains("cX") && !diff.contains("ab") && !diff.contains("\u{1B}[1;1H"))
        #expect(FrameEncoder.encode(second, previous: second, colors: .trueColor).isEmpty)
    }

    @Test func encoderWritesWideCharactersOnce() {
        let wide = grid("あ", "  ")
        let out = String(decoding: FrameEncoder.encode(wide, previous: nil, colors: .palette256), as: UTF8.self)
        #expect(out.filter { $0 == "あ" }.count == 1)
        #expect(out.contains("38;5;"))
    }

    /// 2 桁 2 行の格子（帯の描き方を通さず、Terminal だけを確かめる）。
    private func grid(_ top: String, _ bottom: String) -> Grid {
        let (text, ground) = (Rgb(red: 200, green: 255, blue: 200), Rgb(red: 0, green: 8, blue: 5))
        var grid = Grid.filled(ScreenSize(columns: 2, rows: 2), foreground: text, background: ground)
        grid.write([Segment(top, text)], column: 0, row: 0, background: ground)
        grid.write([Segment(bottom, text)], column: 0, row: 1, background: ground)
        return grid
    }
}
