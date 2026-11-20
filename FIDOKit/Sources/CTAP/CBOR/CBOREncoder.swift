import Foundation

/// Encodes `CBORValue`s in CTAP2 canonical form: shortest integers and lengths, definite lengths only,
/// map keys sorted by major type, then encoded length, then bytewise.
public enum CBOREncoder {
    /// - Throws: `CBOREncodingError.duplicateKey` if a map has the same key twice.
    public static func encode(_ value: CBORValue) throws -> Data {
        var output = Data()
        try encode(value, into: &output)
        return output
    }

    private static func encode(_ value: CBORValue, into output: inout Data) throws {
        switch value {
        case let .unsigned(number):
            appendHead(major: 0, argument: number, to: &output)
        case let .negative(number):
            appendHead(major: 1, argument: number, to: &output)
        case let .bytes(bytes):
            appendHead(major: 2, argument: UInt64(bytes.count), to: &output)
            output.append(bytes)
        case let .text(text):
            let utf8 = Data(text.utf8)
            appendHead(major: 3, argument: UInt64(utf8.count), to: &output)
            output.append(utf8)
        case let .array(items):
            appendHead(major: 4, argument: UInt64(items.count), to: &output)
            for item in items {
                try encode(item, into: &output)
            }
        case let .map(entries):
            var encoded: [(key: Data, entry: CBORMapEntry)] = []
            encoded.reserveCapacity(entries.count)
            for entry in entries {
                encoded.append((try encode(entry.key), entry))
            }
            encoded.sort { canonicalOrder($0.key, $1.key) }
            for (previous, next) in zip(encoded, encoded.dropFirst()) where previous.key == next.key {
                throw CBOREncodingError.duplicateKey(next.entry.key)
            }
            appendHead(major: 5, argument: UInt64(entries.count), to: &output)
            for (key, entry) in encoded {
                output.append(key)
                try encode(entry.value, into: &output)
            }
        case let .bool(flag):
            output.append(flag ? 0xF5 : 0xF4)
        case .null:
            output.append(0xF6)
        }
    }

    /// CTAP2 canonical key order of two encoded keys: major type, then shorter encoding, then bytewise.
    private static func canonicalOrder(_ lhs: Data, _ rhs: Data) -> Bool {
        let lhsMajor = (lhs.first ?? 0) >> 5
        let rhsMajor = (rhs.first ?? 0) >> 5
        if lhsMajor != rhsMajor { return lhsMajor < rhsMajor }
        if lhs.count != rhs.count { return lhs.count < rhs.count }
        return lhs.lexicographicallyPrecedes(rhs)
    }

    /// The initial byte plus the argument in its shortest form.
    static func appendHead(major: UInt8, argument: UInt64, to output: inout Data) {
        let type = major << 5
        switch argument {
        case 0..<24:
            output.append(type | UInt8(argument))
        case 24...0xFF:
            output.append(contentsOf: [type | 24, UInt8(argument)])
        case 0x100...0xFFFF:
            output.append(type | 25)
            appendBigEndian(argument, byteCount: 2, to: &output)
        case 0x1_0000...0xFFFF_FFFF:
            output.append(type | 26)
            appendBigEndian(argument, byteCount: 4, to: &output)
        default:
            output.append(type | 27)
            appendBigEndian(argument, byteCount: 8, to: &output)
        }
    }

    private static func appendBigEndian(_ value: UInt64, byteCount: Int, to output: inout Data) {
        for shift in stride(from: (byteCount - 1) * 8, through: 0, by: -8) {
            output.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }
}
