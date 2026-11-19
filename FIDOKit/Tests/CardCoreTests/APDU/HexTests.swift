import CardCore
import Foundation
import Testing

@Suite("Hex")
struct HexTests {
    @Test("Formats with spaces and compact")
    func format() {
        let data = Data([0x00, 0xA4, 0x04, 0x00])
        #expect(Hex.format(data) == "00 A4 04 00")
        #expect(Hex.compact(data) == "00A40400")
        #expect(Hex.format(Data()) == "")
    }

    @Test("Parses either case and ignores whitespace")
    func parse() throws {
        #expect(try Hex.parse("00 a4 04 00") == Data([0x00, 0xA4, 0x04, 0x00]))
        #expect(try Hex.parse("00A4\n0400") == Data([0x00, 0xA4, 0x04, 0x00]))
        #expect(try Hex.parse("") == Data())
    }

    @Test("Rejects odd length and invalid characters")
    func parseErrors() {
        #expect(throws: HexError.oddLength) { try Hex.parse("ABC") }
        #expect(throws: HexError.invalidCharacter("G")) { try Hex.parse("0G") }
    }
}
