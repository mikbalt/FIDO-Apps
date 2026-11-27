import Foundation

extension Data {
    /// base64url without padding (RFC 4648 §5), the encoding WebAuthn uses for binary fields.
    public var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes base64url without padding. Returns `nil` for padding, standard-alphabet characters or bad length.
    public init?(base64URLEncoded string: String) {
        guard !string.contains("="), !string.contains("+"), !string.contains("/") else { return nil }
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        switch base64.count % 4 {
        case 0: break
        case 2: base64 += "=="
        case 3: base64 += "="
        default: return nil
        }
        self.init(base64Encoded: base64)
    }
}
