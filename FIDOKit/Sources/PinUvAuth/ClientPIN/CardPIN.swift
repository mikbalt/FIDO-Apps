import CryptoKit
import Foundation

/// A validated PIN. Never printed: `description` hides it.
public struct CardPIN: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// UTF-8 of the NFC-normalized PIN.
    public let utf8: Data

    public static let maxUTF8Length = 63

    /// Normalizes to Unicode NFC, then checks `max(4, minPINLength)` ≤ code points and UTF-8 ≤ 63 bytes.
    /// - Throws: `PINError.tooShort` or `.tooLong`.
    public init(_ string: String, minimumLength: Int = 4) throws {
        let normalized = string.precomposedStringWithCanonicalMapping
        let minimum = max(4, minimumLength)
        guard normalized.unicodeScalars.count >= minimum else { throw PINError.tooShort(minimum: minimum) }
        let utf8 = Data(normalized.utf8)
        guard utf8.count <= Self.maxUTF8Length else { throw PINError.tooLong }
        self.utf8 = utf8
    }

    /// The UTF-8 bytes padded with `00` to 64 bytes, as setPIN and changePIN encrypt them.
    public var padded64: Data {
        utf8 + Data(count: 64 - utf8.count)
    }

    /// `LEFT(SHA-256(PIN), 16)`.
    public var hash16: Data {
        Data(SHA256.hash(data: utf8).prefix(16))
    }

    public var description: String { "CardPIN(<redacted>)" }
    public var debugDescription: String { description }
}
