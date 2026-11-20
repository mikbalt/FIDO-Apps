import CardCore
import Foundation

/// A GetInfo response that does not match the CTAP2 definition.
public enum GetInfoError: Error, Equatable, Sendable {
    case notAMap
    case missingVersions
    /// A known key holds a value of the wrong type.
    case invalidField(key: Int, name: String, expected: String)
}

extension GetInfoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAMap: "GetInfo did not return a CBOR map."
        case .missingVersions: "GetInfo has no versions (key 0x01)."
        case let .invalidField(key, name, expected):
            "GetInfo \(name) (key 0x\(Hex.byte(UInt8(truncatingIfNeeded: key)))) is not \(expected)."
        }
    }
}

extension GetInfoError: TraceErrorConvertible {
    public var traceError: TraceError {
        TraceError(domain: .validation, code: "getInfoInvalid", name: "GET_INFO_INVALID",
                   message: errorDescription ?? "GetInfo is invalid.")
    }
}
