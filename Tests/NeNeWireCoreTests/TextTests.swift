import Testing

@testable import NeNeWireCore

/// XML の字句・文字参照・HTML の除去・出だしの切り出し（FR-08・ADR 0005）。
struct TextTests {
    @Test func scannerReadsTagsTextCDATAAndSkipsCommentsAndDeclarations() {
        let events = MarkupScanner.events(
            "<?xml version='1.0'?><!-- c --><a x='1' y=\"&lt;\"><b/>t&amp;u<![CDATA[<raw>]]></a>")
        #expect(
            events == [
                .open(
                    name: "a",
                    attributes: [MarkupAttribute(name: "x", value: "1"), MarkupAttribute(name: "y", value: "<")]),
                .open(name: "b", attributes: []), .close(name: "b"), .text("t&u"), .text("<raw>"), .close(name: "a"),
            ])
    }

    @Test func characterReferencesResolveNamedAndNumericAndKeepUnknown() {
        #expect(
            CharacterReferences.decode("&quot;a&quot; &#39;b&#x27; &hellip; &unknown; & x")
                == "\"a\" 'b' \u{2026} &unknown; & x")
    }

    @Test func plainTextSplitsParagraphsAndDropsFormatCharacters() {
        let html = "<p>Standfirst without a period</p><p>Body\u{2060} one.<br/>Two &amp; three.</p>"
        #expect(PlainText.paragraphs(html: html) == ["Standfirst without a period", "Body one.", "Two & three."])
        #expect(PlainText.from(html: "<b>Bold</b>\u{200B}  text") == "Bold text")
    }

    @Test func ledeKeepsAtMostThreeSentences() {
        let lede = Lede.make(paragraphs: ["One. Two. Three. Four."], headline: "Title")
        #expect(lede == "One. Two. Three.")
    }

    @Test func ledeJoinsJapaneseSentencesWithoutSpaces() {
        let lede = Lede.make(paragraphs: ["最初の文です。次の文です。", "三つ目。四つ目。"], headline: "見出し")
        #expect(lede == "最初の文です。次の文です。三つ目。")
    }

    @Test func ledeStopsBeforeTwoHundredFiftyCharacters() throws {
        let long = String(repeating: "a", count: 200) + "."
        let lede = try #require(Lede.make(paragraphs: [long + " " + long], headline: "T"))
        #expect(lede == long)
        let single = try #require(Lede.make(paragraphs: [String(repeating: "b", count: 400)], headline: "T"))
        #expect(single.count == Lede.maximumLength)
        #expect(single.hasSuffix("\u{2026}"))
    }

    @Test func ledeIsNilWhenEmptyOrSameAsTheHeadline() {
        #expect(Lede.make(paragraphs: [], headline: "Title") == nil)
        #expect(Lede.make(paragraphs: ["  Title  "], headline: "Title") == nil)
        #expect(Lede.make(paragraphs: ["Big"], headline: "Big news today") == nil)
    }
}
