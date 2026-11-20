import CardCore
import CTAP
import Foundation
import Testing

@Suite("Canonical CBOR")
struct CBORCanonicalTests {
    private func hex(_ value: CBORValue) throws -> String {
        Hex.compact(try CBOREncoder.encode(value))
    }

    private func keys(_ value: CBORValue) -> [CBORValue] {
        value.mapEntries?.map(\.key) ?? []
    }

    // MARK: Sort order

    @Test("Mixed int/text keys: integers first, then shorter text, then bytewise")
    func mixedKeys() throws {
        let decoded = try CBORDecoder.decode(CBOREncoder.encode(["up": 1, 2: 2, "a": 3, -5: 4, 24: 5]))
        #expect(keys(decoded.value) == [2, 24, -5, "a", "up"])
    }

    @Test("COSE labels sort as 1, 3, -1, -2, -3")
    func coseLabels() throws {
        let decoded = try CBORDecoder.decode(CBOREncoder.encode([-3: 0, -1: 0, 3: 0, -2: 0, 1: 0]))
        #expect(keys(decoded.value) == [1, 3, -1, -2, -3])
    }

    @Test("rk < up < uv")
    func optionKeys() throws {
        #expect(try hex(["uv": true, "rk": true, "up": true]) == "A362726BF5627570F5627576F5")
    }

    // MARK: Encoder

    @Test("Shortest integer and length forms at each boundary")
    func shortestForms() throws {
        #expect(try hex(23) == "17")
        #expect(try hex(24) == "1818")
        #expect(try hex(256) == "190100")
        #expect(try hex(-24) == "37")
        #expect(try hex(-25) == "3818")
        #expect(try hex(.bytes(Data(count: 24))).hasPrefix("5818"))
        #expect(try hex(.null) == "F6")
    }

    @Test("Duplicate keys are an error")
    func duplicateKeys() {
        #expect(throws: CBOREncodingError.duplicateKey("rk")) {
            try CBOREncoder.encode(["rk": true, "up": true, "rk": false])
        }
    }

    // MARK: Decoder rejections

    @Test(
        "Rejects types and encodings CTAP does not use",
        arguments: [
            ("F93C00", CBORDecodingError.floatNotSupported(offset: 0)),
            ("FB3FF0000000000000", .floatNotSupported(offset: 0)),
            ("C11A514B67B0", .tagNotSupported(offset: 0)),
            ("F7", .undefinedNotSupported(offset: 0)),
            ("9F0102FF", .indefiniteLength(offset: 0)),
            ("BF6161F5FF", .indefiniteLength(offset: 0)),
            ("7F6161FF", .indefiniteLength(offset: 0)),
            ("FF", .indefiniteLength(offset: 0)),
            ("1C", .reservedAdditionalInfo(offset: 0)),
            ("62C328", .invalidUTF8(offset: 0)),
            ("A2010001F5", .duplicateKey(offset: 3)),
            ("F0", .simpleValueNotSupported(value: 16, offset: 0)),
        ]
    )
    func rejects(hex: String, error: CBORDecodingError) throws {
        let bytes = try Hex.parse(hex)
        #expect(throws: error) { try CBORDecoder.decode(bytes) }
    }

    @Test(
        "Truncated input is rejected",
        arguments: ["", "18", "19 01", "1B 00000000", "43 0102", "82 01", "A1 01", "62 61"]
    )
    func truncated(hex: String) throws {
        let bytes = try Hex.parse(hex)
        #expect(throws: CBORDecodingError.self) { try CBORDecoder.decode(bytes) }
        do {
            _ = try CBORDecoder.decode(bytes)
        } catch let error as CBORDecodingError {
            guard case .truncated = error else {
                Issue.record("Expected .truncated, got \(error)")
                return
            }
        }
    }

    @Test("Deeply nested input is rejected, not a stack overflow")
    func hostileNesting() {
        let bytes = Data(repeating: 0x81, count: 10_000) + Data([0x00])
        #expect(throws: CBORDecodingError.nestingTooDeep(offset: CBORDecoder.maxNestingDepth)) {
            try CBORDecoder.decode(bytes)
        }
    }

    // MARK: Bytes consumed

    @Test("bytesConsumed stops at the end of the item, leaving trailing bytes")
    func bytesConsumed() throws {
        // A COSE-like map followed by unrelated bytes, as inside authData.
        let item = try CBOREncoder.encode([1: 2, 3: -7, -1: 1, -2: .bytes(Data(count: 32))])
        let data = item + Data([0xA1, 0x01, 0x02, 0xDE, 0xAD])
        let result = try CBORDecoder.decode(data)
        #expect(result.bytesConsumed == item.count)
        #expect(result.value[-2] == .bytes(Data(count: 32)))
        #expect(throws: CBORDecodingError.trailingBytes(offset: item.count)) { try CBORDecoder.decodeExactly(data) }
    }

    @Test("Decoding works on a Data slice with a non-zero start index")
    func slice() throws {
        let data = Data([0xFF, 0xFF, 0x82, 0x01, 0x02])
        let result = try CBORDecoder.decode(data.dropFirst(2))
        #expect(result.value == [1, 2])
        #expect(result.bytesConsumed == 3)
    }

    @Test("Full 64-bit range round-trips; intValue is nil outside Int")
    func fullRange() throws {
        let max = try CBORDecoder.decode(Hex.parse("1BFFFFFFFFFFFFFFFF")).value
        let min = try CBORDecoder.decode(Hex.parse("3BFFFFFFFFFFFFFFFF")).value
        #expect(max == .unsigned(.max))
        #expect(min == .negative(.max))
        #expect(max.intValue == nil)
        #expect(CBORValue(Int.min).intValue == Int.min)
        #expect(CBORValue(-1) == .negative(0))
    }

    // MARK: Diagnostic notation

    @Test("Plain-text dump: single line, multiline and truncated bytes")
    func diagnostic() {
        let value: CBORValue = [1: ["FIDO_2_0"], 3: .bytes(Data([0x2F, 0xC0, 0x57])), 4: ["rk": true]]
        #expect(CBORDiagnostic.format(value, maxBytes: 2) == #"{1: ["FIDO_2_0"], 3: h'2FC0…', 4: {"rk": true}}"#)
        #expect(CBORDiagnostic.format([-1: "a\"b"]) == #"{-1: "a\"b"}"#)
        #expect(CBORDiagnostic.format([1: [2], 3: [:]], multiline: true) == """
            {
              1: [
                2
              ],
              3: {}
            }
            """)
        #expect(CBORDiagnostic.format(.null) == "null")
    }
}
