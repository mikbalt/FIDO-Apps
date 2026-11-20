import Foundation

/// Decodes one CBOR item. Types CTAP does not use (floats, tags, `undefined`, indefinite lengths) are
/// rejected. Encodings that are valid but not canonical are accepted, so a slightly off card still works.
public enum CBORDecoder {
    /// Guards against stack exhaustion on hostile input. Far above the CTAP limit of 4.
    public static let maxNestingDepth = 32

    /// Decodes the item at the start of `data`. Trailing bytes are left alone; see `bytesConsumed`.
    /// - Throws: `CBORDecodingError`.
    public static func decode(_ data: Data) throws -> CBORDecodeResult {
        var reader = Reader(bytes: [UInt8](data))
        let value = try reader.item(depth: 0)
        return CBORDecodeResult(value: value, bytesConsumed: reader.position)
    }

    /// Decodes `data`, which must hold exactly one item.
    /// - Throws: `CBORDecodingError`, including `trailingBytes`.
    public static func decodeExactly(_ data: Data) throws -> CBORDecodeResult {
        let result = try decode(data)
        guard result.bytesConsumed == data.count else {
            throw CBORDecodingError.trailingBytes(offset: result.bytesConsumed)
        }
        return result
    }

    private struct Reader {
        let bytes: [UInt8]
        var position = 0

        mutating func item(depth: Int) throws -> CBORValue {
            let start = position
            let initial = try byte(itemStart: start)
            let major = initial >> 5
            let info = initial & 0x1F

            if major == 7 {
                return try simple(info: info, start: start)
            }
            if major == 6 {
                throw CBORDecodingError.tagNotSupported(offset: start)
            }
            let argument = try argument(info: info, start: start)

            switch major {
            case 0:
                return .unsigned(argument)
            case 1:
                return .negative(argument)
            case 2:
                return .bytes(Data(try take(argument, itemStart: start)))
            case 3:
                let utf8 = try take(argument, itemStart: start)
                // Decoding replaces invalid sequences with U+FFFD, so only valid UTF-8 round-trips exactly.
                let text = String(decoding: utf8, as: UTF8.self)
                guard text.utf8.elementsEqual(utf8) else {
                    throw CBORDecodingError.invalidUTF8(offset: start)
                }
                return .text(text)
            case 4:
                guard depth < CBORDecoder.maxNestingDepth else { throw CBORDecodingError.nestingTooDeep(offset: start) }
                let count = try count(argument, start: start)
                var items: [CBORValue] = []
                for _ in 0..<count {
                    items.append(try item(depth: depth + 1))
                }
                return .array(items)
            default:
                guard depth < CBORDecoder.maxNestingDepth else { throw CBORDecodingError.nestingTooDeep(offset: start) }
                return try map(count: try count(argument, start: start), depth: depth)
            }
        }

        private mutating func map(count: Int, depth: Int) throws -> CBORValue {
            var entries: [CBORMapEntry] = []
            var seenKeys: Set<ArraySlice<UInt8>> = []
            for _ in 0..<count {
                let keyStart = position
                let key = try item(depth: depth + 1)
                let keyBytes = bytes[keyStart..<position]
                guard seenKeys.insert(keyBytes).inserted else {
                    throw CBORDecodingError.duplicateKey(offset: keyStart)
                }
                entries.append(CBORMapEntry(key: key, value: try item(depth: depth + 1)))
            }
            return .map(entries)
        }

        private mutating func simple(info: UInt8, start: Int) throws -> CBORValue {
            switch info {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22: return .null
            case 23: throw CBORDecodingError.undefinedNotSupported(offset: start)
            case 24: throw CBORDecodingError.simpleValueNotSupported(value: try byte(itemStart: start), offset: start)
            case 25, 26, 27: throw CBORDecodingError.floatNotSupported(offset: start)
            case 28, 29, 30: throw CBORDecodingError.reservedAdditionalInfo(offset: start)
            case 31: throw CBORDecodingError.indefiniteLength(offset: start)
            default: throw CBORDecodingError.simpleValueNotSupported(value: info, offset: start)
            }
        }

        /// The argument that follows the initial byte.
        private mutating func argument(info: UInt8, start: Int) throws -> UInt64 {
            switch info {
            case 0..<24: UInt64(info)
            case 24: UInt64(try byte(itemStart: start))
            case 25: try bigEndian(byteCount: 2, itemStart: start)
            case 26: try bigEndian(byteCount: 4, itemStart: start)
            case 27: try bigEndian(byteCount: 8, itemStart: start)
            case 31: throw CBORDecodingError.indefiniteLength(offset: start)
            default: throw CBORDecodingError.reservedAdditionalInfo(offset: start)
            }
        }

        private func count(_ argument: UInt64, start: Int) throws -> Int {
            // Each element takes at least one byte, so a count beyond the remaining input is truncated.
            guard argument <= UInt64(bytes.count - position) else { throw CBORDecodingError.truncated(offset: start) }
            return Int(argument)
        }

        private mutating func byte(itemStart: Int) throws -> UInt8 {
            guard position < bytes.count else { throw CBORDecodingError.truncated(offset: itemStart) }
            defer { position += 1 }
            return bytes[position]
        }

        private mutating func bigEndian(byteCount: Int, itemStart: Int) throws -> UInt64 {
            var value: UInt64 = 0
            for _ in 0..<byteCount {
                value = value << 8 | UInt64(try byte(itemStart: itemStart))
            }
            return value
        }

        private mutating func take(_ length: UInt64, itemStart: Int) throws -> ArraySlice<UInt8> {
            guard length <= UInt64(Int.max) else { throw CBORDecodingError.lengthTooLarge(offset: itemStart) }
            guard Int(length) <= bytes.count - position else { throw CBORDecodingError.truncated(offset: itemStart) }
            defer { position += Int(length) }
            return bytes[position..<position + Int(length)]
        }
    }
}
