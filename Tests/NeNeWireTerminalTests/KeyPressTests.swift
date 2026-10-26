import Testing

@testable import NeNeWireTerminal

/// 文字を打つ画面のキーの読み取り（ADR 0011）。
struct KeyPressTests {
    @Test func keysAndTextAreReadInOrder() {
        var carry: [UInt8] = []
        let bytes = Array("a朝\t\r\u{7F}\u{1B}[A\u{1B}OD\u{1B}[1;5C".utf8)
        #expect(
            KeyPress.decode(bytes, carry: &carry) == [
                .character("a"), .character("朝"), .tab, .enter, .backspace, .up, .left,
            ])
        #expect(carry.isEmpty)
    }

    @Test func aLoneEscapeIsTheEscapeKey() {
        var carry: [UInt8] = []
        #expect(KeyPress.decode([0x1B], carry: &carry) == [.escape])
        #expect(KeyPress.decode([0x1B, UInt8(ascii: "x")], carry: &carry) == [.escape, .character("x")])
    }

    @Test func aCharacterSplitAcrossReadsIsCarriedOver() {
        var carry: [UInt8] = []
        let bytes = Array("日本".utf8)
        #expect(KeyPress.decode(Array(bytes[0..<4]), carry: &carry) == [.character("日")])
        #expect(carry.count == 1)
        #expect(KeyPress.decode(Array(bytes[4...]), carry: &carry) == [.character("本")])
        #expect(carry.isEmpty)
    }

    @Test func theTickerOpensSettingsWithS() {
        #expect(KeyIntent.decode(Array("s".utf8)) == [.settings])
        #expect(KeyIntent.decode(Array("tT".utf8)) == [.toggleTranslation, .toggleTranslation])
    }
}
