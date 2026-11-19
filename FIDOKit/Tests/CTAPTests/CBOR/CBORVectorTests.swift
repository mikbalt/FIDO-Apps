import CardCore
@testable import CTAP
import Foundation
import Testing

@Suite("CBOR vectors from python-fido2")
struct CBORVectorTests {
    @Test("The vector file is present and complete")
    func vectorsPresent() {
        #expect(CTAPFixtures.cborVectors.count == Self.swiftValues.count)
        #expect(Set(CTAPFixtures.cborVectors.map(\.name)) == Set(Self.swiftValues.keys))
    }

    @Test("decode(hex) then encode gives back the same hex, and diag matches", arguments: CTAPFixtures.cborVectors)
    func roundTrip(vector: CTAPFixtures.Vector) throws {
        let bytes = try Hex.parse(vector.hex)
        let result = try CBORDecoder.decodeExactly(bytes)
        #expect(result.canonicality.isCanonical)
        #expect(result.bytesConsumed == bytes.count)
        #expect(Hex.compact(try CBOREncoder.encode(result.value)) == vector.hex)
        #expect(CBORDiagnostic.format(result.value) == vector.diag)
    }

    @Test("Values built in Swift encode to the Python hex", arguments: CTAPFixtures.cborVectors)
    func swiftValue(vector: CTAPFixtures.Vector) throws {
        let value = try #require(Self.swiftValues[vector.name], "No Swift value for \(vector.name)")
        #expect(Hex.compact(try CBOREncoder.encode(value)) == vector.hex)
    }

    /// The same cases as `tools/vectors/gen_cbor_vectors.py`, built independently. Maps are written in a
    /// non-canonical order on purpose.
    static let swiftValues: [String: CBORValue] = {
        var values: [String: CBORValue] = [:]
        for number: UInt64 in [0, 23, 24, 255, 256, 65535, 65536, 0xFFFF_FFFF, 0x1_0000_0000, .max] {
            values["uint_\(number)"] = .unsigned(number)
        }
        for magnitude: UInt64 in [1, 24, 25, 256, 257] {
            values["nint_\(magnitude)"] = .negative(magnitude - 1)
        }
        values["nint_18446744073709551616"] = .negative(.max)
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        for length in [0, 23, 24, 255, 256] {
            values["bytes_len_\(length)"] = .bytes(Data((0..<length).map { UInt8($0 % 256) }))
            values["text_len_\(length)"] = .text(String((0..<length).map { alphabet[$0 % 26] }))
        }
        values["true"] = true
        values["false"] = false
        values["text_escapes"] = "quote \" backslash \\ newline \n tab \t"
        values["text_non_ascii"] = "Zürich ✓"
        values["array_empty"] = []
        values["array_nested"] = [1, [2, 3], [[4]], []]
        values["map_empty"] = [:]
        values["map_nested"] = [2: [true, false], 1: [2: [3: "deep"]]]
        values["map_mixed_int_text_keys"] = ["b": 1, 10: 2, "a": 3, -1: 4, 1: 5, "aa": 6]
        values["map_rk_up_uv"] = ["uv": false, "up": true, "rk": true]
        values["cose_ec2_key"] = [
            -3: .bytes(Data(0x20..<0x40)), -2: .bytes(Data(0x00..<0x20)), -1: 1, 3: -7, 1: 2,
        ]
        values["getinfo_request"] = 4
        values["getinfo_response"] = [
            10: [["type": "public-key", "alg": -7]],
            6: [2, 1],
            5: 1200,
            4: ["clientPin": false, "plat": false, "up": true, "rk": true],
            3: .bytes(Data([0x2F, 0xC0, 0x57, 0x9F, 0x81, 0x13, 0x47, 0xEA, 0xB1, 0x16, 0xBB, 0x5A, 0x8D, 0xB9, 0x20, 0x2A])),
            1: ["FIDO_2_0", "FIDO_2_1"],
        ]
        return values
    }()
}
