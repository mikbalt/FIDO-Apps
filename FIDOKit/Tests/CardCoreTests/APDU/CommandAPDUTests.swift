import CardCore
import Foundation
import Testing

@Suite("CommandAPDU encoding")
struct CommandAPDUTests {
    private func hex(_ data: Data) -> String { Hex.compact(data) }

    // MARK: Case 1 — no data, no Le

    @Test("Case 1 is the header only, in both forms", arguments: LengthForm.allCases)
    func case1(form: LengthForm) throws {
        let apdu = CommandAPDU(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00)
        #expect(hex(try apdu.encoded(form)) == "00A40400")
    }

    // MARK: Case 2 — Le only

    @Test("Case 2 short")
    func case2Short() throws {
        #expect(hex(try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 5).encoded(.short)) == "00C0000005")
        #expect(hex(try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 255).encoded(.short)) == "00C00000FF")
    }

    @Test("Case 2 short: Le 256 is encoded as 00")
    func case2ShortLe256() throws {
        #expect(hex(try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 256).encoded(.short)) == "00C0000000")
    }

    @Test("Case 2 short: Le above 256 throws")
    func case2ShortLeTooLarge() {
        #expect(throws: APDUError.leOutOfRange(le: 257, form: .short)) {
            try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 257).encoded(.short)
        }
    }

    @Test("Case 2 extended is 00 Le1 Le2")
    func case2Extended() throws {
        #expect(hex(try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 5).encoded(.extended)) == "00C00000000005")
        #expect(hex(try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 256).encoded(.extended)) == "00C00000000100")
    }

    @Test("Case 2 extended: Le 65536 is encoded as 00 00")
    func case2ExtendedLe65536() throws {
        #expect(hex(try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: 65536).encoded(.extended)) == "00C00000000000")
    }

    @Test("Le outside 1…65536 throws", arguments: [0, -1, 65537])
    func leOutOfRange(le: Int) {
        #expect(throws: APDUError.leOutOfRange(le: le, form: .extended)) {
            try CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0, p2: 0, le: le).encoded(.extended)
        }
    }

    // MARK: Case 3 — data only

    @Test("Case 3 short")
    func case3Short() throws {
        let apdu = CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data([0x04]))
        #expect(hex(try apdu.encoded(.short)) == "801000000104")
    }

    @Test("Case 3 short: Lc 255 is accepted")
    func case3ShortLc255() throws {
        let data = Data(repeating: 0xAB, count: 255)
        let encoded = try CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: data).encoded(.short)
        #expect(encoded.count == 4 + 1 + 255)
        #expect(encoded[encoded.startIndex + 4] == 0xFF)
    }

    @Test("Case 3 short: Lc 256 throws")
    func case3ShortLc256() {
        #expect(throws: APDUError.dataTooLong(count: 256, form: .short)) {
            try CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data(count: 256)).encoded(.short)
        }
    }

    @Test("Case 3 extended is 00 Lc1 Lc2 data")
    func case3Extended() throws {
        let apdu = CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data([0x04]))
        #expect(hex(try apdu.encoded(.extended)) == "80100000000001" + "04")

        let large = try CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data(count: 256)).encoded(.extended)
        #expect(hex(large.prefix(7)) == "80100000000100")
        #expect(large.count == 7 + 256)
    }

    @Test("Data longer than 65535 bytes throws in extended form")
    func dataTooLongExtended() throws {
        let max = try CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data(count: 65535)).encoded(.extended)
        #expect(hex(max.prefix(7)) == "8010000000FFFF")
        #expect(throws: APDUError.dataTooLong(count: 65536, form: .extended)) {
            try CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data(count: 65536)).encoded(.extended)
        }
    }

    // MARK: Case 4 — data and Le

    @Test("Case 4 short: SELECT FIDO")
    func case4Short() throws {
        let select = CommandAPDU(
            cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00,
            data: try Hex.parse("A0000006472F0001"), le: 256
        )
        #expect(hex(try select.encoded(.short)) == "00A4040008A0000006472F000100")
    }

    @Test("Case 4 extended is 00 Lc1 Lc2 data Le1 Le2")
    func case4Extended() throws {
        let apdu = CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data([0x04]), le: 256)
        #expect(hex(try apdu.encoded(.extended)) == "80100000000001" + "04" + "0100")
    }

    @Test("Case 4 extended: Le 65536 is encoded as 00 00")
    func case4ExtendedLe65536() throws {
        let apdu = CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data([0x04]), le: 65536)
        #expect(hex(try apdu.encoded(.extended)) == "80100000000001" + "04" + "0000")
    }
}
