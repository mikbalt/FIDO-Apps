import Foundation

/// Hex parsing and formatting.
public enum Hex {
    /// Formats bytes as uppercase hex pairs separated by spaces, e.g. `00 A4 04 00`.
    public static func format(_ data: Data, separator: String = " ") -> String {
        data.map { byteString($0) }.joined(separator: separator)
    }

    /// Uppercase hex without separators, as used in trace JSON, e.g. `00A40400`.
    public static func compact(_ data: Data) -> String {
        format(data, separator: "")
    }

    /// Parses hex digits in either case. Whitespace is ignored.
    public static func parse(_ string: String) throws -> Data {
        var bytes = Data()
        var high: UInt8?
        for character in string where !character.isWhitespace {
            guard character.isASCII, let nibble = character.hexDigitValue.map(UInt8.init) else {
                throw HexError.invalidCharacter(character)
            }
            if let value = high {
                bytes.append(value << 4 | nibble)
                high = nil
            } else {
                high = nibble
            }
        }
        guard high == nil else { throw HexError.oddLength }
        return bytes
    }

    private static let digits = Array("0123456789ABCDEF")

    /// One byte as two uppercase hex digits, e.g. `04`.
    public static func byte(_ byte: UInt8) -> String {
        byteString(byte)
    }

    private static func byteString(_ byte: UInt8) -> String {
        String([digits[Int(byte >> 4)], digits[Int(byte & 0x0F)]])
    }
}
