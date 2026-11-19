/// ISO 7816-4 length encoding for Lc and Le.
public enum LengthForm: String, Codable, Sendable, CaseIterable {
    /// One-byte Lc (1…255) and Le (1…256, where 256 is encoded as `00`).
    case short
    /// Three-byte Lc (`00 Lc1 Lc2`) and two- or three-byte Le (65536 is encoded as `00 00`).
    case extended

    /// Largest Le this form can express.
    public var maxLe: Int {
        switch self {
        case .short: 256
        case .extended: 65536
        }
    }

    /// Largest Lc this form can express.
    public var maxLc: Int {
        switch self {
        case .short: 255
        case .extended: 65535
        }
    }
}
