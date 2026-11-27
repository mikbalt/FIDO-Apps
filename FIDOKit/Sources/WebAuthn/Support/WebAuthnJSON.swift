import Foundation

/// JSON coders for the WebAuthn types: every `Data` field is base64url without padding.
///
/// Always encode and decode the option and result types with these, not a plain `JSONEncoder`.
public enum WebAuthnJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dataEncodingStrategy = .custom { data, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(data.base64URLEncoded)
        }
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let data = Data(base64URLEncoded: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not base64url without padding.")
            }
            return data
        }
        return decoder
    }
}
