import CardCore
import Foundation
import Testing

@Suite("ResponseAPDU and StatusWord")
struct ResponseAPDUTests {
    @Test("Parsing rejects input shorter than 2 bytes", arguments: [Data(), Data([0x90])])
    func rejectsShortInput(raw: Data) {
        #expect(throws: APDUError.responseTooShort(count: raw.count)) {
            try ResponseAPDU(raw: raw)
        }
    }

    @Test("Status word only")
    func statusOnly() throws {
        let response = try ResponseAPDU(raw: Data([0x6A, 0x82]))
        #expect(response.data.isEmpty)
        #expect(response.sw == .fileNotFound)
    }

    @Test("Data and status word")
    func dataAndStatus() throws {
        let response = try ResponseAPDU(raw: try Hex.parse("4649444F5F325F30 9000"))
        #expect(String(decoding: response.data, as: UTF8.self) == "FIDO_2_0")
        #expect(response.sw.isSuccess)
        #expect(response.raw == (try Hex.parse("4649444F5F325F309000")))
    }

    @Test("SW1, SW2 and success")
    func swHelpers() {
        let sw = StatusWord(sw1: 0x61, sw2: 0x10)
        #expect(sw.rawValue == 0x6110)
        #expect(sw.sw1 == 0x61)
        #expect(sw.sw2 == 0x10)
        #expect(!sw.isSuccess)
        #expect(StatusWord.success.isSuccess)
        #expect(StatusWord(sw1: 0x90, sw2: 0x01).isSuccess == false)
        #expect(sw.hex == "6110")
    }

    @Test("Display names", arguments: [
        (0x9000, "Success"),
        (0x6110, "16 response bytes available"),
        (0x6100, "256 response bytes available"),
        (0x6C08, "Wrong Le, exact length 8"),
        (0x6700, "Wrong length"),
        (0x6985, "Conditions of use not satisfied"),
        (0x6A80, "Incorrect data"),
        (0x6A82, "File or application not found"),
        (0x6D00, "INS not supported"),
        (0x6E00, "CLA not supported"),
        (0x9100, "NFCCTAP status update"),
    ] as [(UInt16, String)])
    func displayNames(raw: UInt16, name: String) {
        #expect(StatusWord(rawValue: raw).displayName == name)
    }

    @Test("Unknown status word has no display name")
    func unknownName() {
        #expect(StatusWord(rawValue: 0x6F00).displayName == nil)
        #expect(StatusWord(rawValue: 0x6F00).description == "6F00")
    }
}
