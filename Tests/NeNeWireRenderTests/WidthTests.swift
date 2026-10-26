import Testing

@testable import NeNeWireRender

/// 全角の幅・折り返し・切り詰め（FR-04・ADR 0006）。
struct WidthTests {
    @Test func widthsFollowEastAsianWidth() {
        #expect(CellWidth.of("A") == 1)
        #expect(CellWidth.of("あ") == 2)
        #expect(CellWidth.of("漢") == 2)
        #expect(CellWidth.of("Ａ") == 2)
        #expect(CellWidth.of("ｱ") == 1)
        #expect(CellWidth.of("─") == 1)
        #expect(CellWidth.of("😀") == 2)
        #expect(CellWidth.of("e\u{301}") == 1)
        #expect(CellWidth.of("\u{200B}") == 0)
        #expect(CellWidth.of("日本語 abc") == 10)
    }

    @Test func tableIsSortedAndDisjoint() {
        let ranges = EastAsianWidth.wide
        #expect(zip(ranges, ranges.dropFirst()).allSatisfy { $0.upperBound + 1 < $1.lowerBound })
        #expect(CellWidth.isWide(0x3042))
        #expect(!CellWidth.isWide(0x41))
    }

    @Test func japaneseWrapsByCellsAndNeverStartsALineWithPunctuation() {
        let lines = TextLayout.wrap("あいうえおかきくけこ。さしす", width: 10)
        #expect(lines == ["あいうえお", "かきくけ", "こ。さしす"])
        #expect(lines.allSatisfy { CellWidth.of($0) <= 10 })
    }

    @Test func englishWrapsAtSpacesAndBreaksOverlongWords() {
        #expect(TextLayout.wrap("The quick brown fox jumps", width: 10) == ["The quick", "brown fox", "jumps"])
        #expect(TextLayout.wrap("abcdefghijklmnop", width: 6) == ["abcdef", "ghijkl", "mnop"])
    }

    @Test func fitTruncatesWithEllipsisWithinWidth() {
        #expect(TextLayout.fit("short", width: 10) == "short")
        #expect(TextLayout.fit("あいうえお", width: 7) == "あいう…")
        #expect(CellWidth.of(TextLayout.fit("あいうえお", width: 6)) <= 6)
    }

    @Test func gridKeepsWideCharactersWholeWhenOverwritten() {
        let color = Rgb(red: 1, green: 2, blue: 3)
        var grid = Grid.filled(ScreenSize(columns: 4, rows: 1), foreground: color, background: color)
        #expect(grid.write([Segment("あい", color)], column: 0, row: 0, background: color) == 4)
        grid.write([Segment("x", color)], column: 1, row: 0, background: color)
        #expect(grid[0, 0].glyph == .narrow(" "))
        #expect(grid[1, 0].glyph == .narrow("x"))
        #expect(grid[2, 0].glyph == .wide("い"))
        #expect(grid[3, 0].glyph == .continuation)
        #expect(grid.write([Segment("うえ", color)], column: 3, row: 0, background: color) == 0)
    }
}
