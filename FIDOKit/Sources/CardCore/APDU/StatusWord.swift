import Foundation

/// The two-byte ISO 7816-4 status word (SW1 SW2) that ends every response.
public struct StatusWord: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public init(sw1: UInt8, sw2: UInt8) {
        self.rawValue = UInt16(sw1) << 8 | UInt16(sw2)
    }

    public var sw1: UInt8 { UInt8(rawValue >> 8) }
    public var sw2: UInt8 { UInt8(rawValue & 0xFF) }

    public var isSuccess: Bool { self == .success }

    /// Uppercase hex without spaces, e.g. `9000`.
    public var hex: String { Hex.compact(Data([sw1, sw2])) }

    /// Human-readable meaning, or `nil` for status words without a known name.
    public var displayName: String? {
        switch sw1 {
        case 0x61: return "\(sw2 == 0 ? 256 : Int(sw2)) response bytes available"
        case 0x6C: return "Wrong Le, exact length \(sw2 == 0 ? 256 : Int(sw2))"
        default: break
        }
        switch self {
        case .success: return "Success"
        case .wrongLength: return "Wrong length"
        case .conditionsNotSatisfied: return "Conditions of use not satisfied"
        case .incorrectData: return "Incorrect data"
        case .fileNotFound: return "File or application not found"
        case .insNotSupported: return "INS not supported"
        case .claNotSupported: return "CLA not supported"
        case .nfcctapStatusUpdate: return "NFCCTAP status update"
        default: return nil
        }
    }

    /// A stable identifier for trace errors, e.g. `FILE_NOT_FOUND`, or `SW_6A86` for unnamed status words.
    public var symbolicName: String {
        switch sw1 {
        case 0x61: return "BYTES_REMAINING"
        case 0x6C: return "WRONG_LE"
        default: break
        }
        switch self {
        case .success: return "SUCCESS"
        case .wrongLength: return "WRONG_LENGTH"
        case .conditionsNotSatisfied: return "CONDITIONS_NOT_SATISFIED"
        case .incorrectData: return "INCORRECT_DATA"
        case .fileNotFound: return "FILE_NOT_FOUND"
        case .insNotSupported: return "INS_NOT_SUPPORTED"
        case .claNotSupported: return "CLA_NOT_SUPPORTED"
        case .nfcctapStatusUpdate: return "NFCCTAP_STATUS_UPDATE"
        default: return "SW_\(hex)"
        }
    }

    public static let success = StatusWord(rawValue: 0x9000)
    public static let wrongLength = StatusWord(rawValue: 0x6700)
    public static let conditionsNotSatisfied = StatusWord(rawValue: 0x6985)
    public static let incorrectData = StatusWord(rawValue: 0x6A80)
    public static let fileNotFound = StatusWord(rawValue: 0x6A82)
    public static let insNotSupported = StatusWord(rawValue: 0x6D00)
    public static let claNotSupported = StatusWord(rawValue: 0x6E00)
    public static let nfcctapStatusUpdate = StatusWord(rawValue: 0x9100)
}

extension StatusWord: CustomStringConvertible {
    public var description: String {
        displayName.map { "\(hex) \($0)" } ?? hex
    }
}

/// Encoded as an uppercase hex string, e.g. `"9000"`.
extension StatusWord: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let bytes = try Hex.parse(try container.decode(String.self))
        guard bytes.count == 2 else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Status word must be 2 bytes, got \(bytes.count)."
            )
        }
        self.init(sw1: bytes[bytes.startIndex], sw2: bytes[bytes.startIndex + 1])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
