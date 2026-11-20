import CardCore
import Foundation

/// A CTAP response the client cannot use.
public enum CTAPClientError: Error, Equatable, Sendable {
    /// SW `9000` but no status byte.
    case missingStatus(label: String)
    /// The body after the status byte is not CBOR this client accepts.
    case invalidCBOR(label: String, CBORDecodingError)
    /// The request parameters could not be encoded.
    case invalidRequest(label: String, CBOREncodingError)
    /// The body decoded, but does not have the shape the command defines.
    case unexpectedResponse(label: String, reason: String)
}

extension CTAPClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingStatus(label): "\(label): the card returned no CTAP status byte."
        case let .invalidCBOR(label, error): "\(label): the response is not valid CBOR. \(error)"
        case let .invalidRequest(label, error): "\(label): the request could not be encoded. \(error)"
        case let .unexpectedResponse(label, reason): "\(label): unexpected response. \(reason)"
        }
    }
}

extension CTAPClientError: TraceErrorConvertible {
    public var traceError: TraceError {
        let (code, name): (String, String) = switch self {
        case .missingStatus: ("missingStatus", "CTAP_MISSING_STATUS")
        case .invalidCBOR: ("invalidCBOR", "CTAP_INVALID_CBOR")
        case .invalidRequest: ("invalidRequest", "CTAP_INVALID_REQUEST")
        case .unexpectedResponse: ("unexpectedResponse", "CTAP_UNEXPECTED_RESPONSE")
        }
        return TraceError(domain: .validation, code: code, name: name, message: errorDescription ?? name)
    }
}
