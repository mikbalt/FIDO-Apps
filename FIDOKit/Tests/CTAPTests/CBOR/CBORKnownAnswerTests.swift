import CardCore
import CTAP
import Foundation
import Testing

/// Known encodings, checked against RFC 8949 Appendix A and CTAP2 canonical form.
@Suite("CBOR known answers")
struct CBORKnownAnswerTests {
    @Test(
        "Integer boundaries encode in the shortest form and round-trip",
        arguments: [
            (CBORValue(0), "00"), (23, "17"), (24, "1818"), (255, "18FF"), (256, "190100"),
            (65535, "19FFFF"), (65536, "1A00010000"), (.unsigned(0xFFFF_FFFF), "1AFFFFFFFF"),
            (.unsigned(0x1_0000_0000), "1B0000000100000000"), (.unsigned(.max), "1BFFFFFFFFFFFFFFFF"),
            (-1, "20"), (-24, "37"), (-25, "3818"), (-256, "38FF"), (-257, "390100"),
            (.negative(.max), "3BFFFFFFFFFFFFFFFF"),
        ] as [(CBORValue, String)]
    )
    func integers(value: CBORValue, hex: String) throws {
        try check(value, hex)
    }

    @Test(
        "Byte and text string length boundaries use the shortest length form",
        arguments: [
            (0, "40", "60"), (23, "57", "77"), (24, "5818", "7818"), (255, "58FF", "78FF"),
            (256, "590100", "790100"), (65535, "59FFFF", "79FFFF"), (65536, "5A00010000", "7A00010000"),
        ]
    )
    func lengths(length: Int, bytesHead: String, textHead: String) throws {
        let bytes = try CBOREncoder.encode(.bytes(Data(count: length)))
        #expect(Hex.compact(bytes.prefix(bytesHead.count / 2)) == bytesHead)
        #expect(bytes.count == bytesHead.count / 2 + length)
        let text = try CBOREncoder.encode(.text(String(repeating: "a", count: length)))
        #expect(Hex.compact(text.prefix(textHead.count / 2)) == textHead)
        #expect(try CBORDecoder.decodeExactly(text).value == .text(String(repeating: "a", count: length)))
    }

    @Test("Simple values, arrays, maps and text round-trip")
    func structures() throws {
        try check(true, "F5")
        try check(false, "F4")
        try check(.null, "F6")
        try check([], "80")
        try check([1, [2, 3], [[4]]], "83018202038181 04".replacingOccurrences(of: " ", with: ""))
        try check([:], "A0")
        try check("Zürich", "675AC3BC72696368")
        try check(.bytes(Data([0x01, 0x02])), "420102")
    }

    @Test("A COSE EC2 key built out of order encodes canonically")
    func coseKey() throws {
        let x = Data(0x00..<0x20)
        let y = Data(0x20..<0x40)
        let key: CBORValue = [-3: .bytes(y), -2: .bytes(x), -1: 1, 3: -7, 1: 2]
        let encoded = try CBOREncoder.encode(key)
        #expect(Hex.compact(encoded) == "A5010203262001215820" + Hex.compact(x) + "225820" + Hex.compact(y))
        // Decoded maps keep the wire order, so compare by re-encoding.
        let decoded = try CBORDecoder.decodeExactly(encoded).value
        #expect(decoded.mapEntries?.map(\.key) == [1, 3, -1, -2, -3])
        #expect(try CBOREncoder.encode(decoded) == encoded)
    }

    private func check(_ value: CBORValue, _ hex: String) throws {
        let encoded = try CBOREncoder.encode(value)
        #expect(Hex.compact(encoded) == hex)
        let decoded = try CBORDecoder.decodeExactly(encoded)
        #expect(decoded.value == value)
        #expect(decoded.bytesConsumed == encoded.count)
    }
}
