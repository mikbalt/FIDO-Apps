import CardCore
import Foundation

/// The card answered a CTAP command with a non-zero status byte.
public struct CTAPError: Error, Equatable, Sendable {
    public let code: UInt8
    /// From the study guide §9 table, e.g. `CTAP2_ERR_PIN_INVALID`.
    public let name: String
    /// Extra context for the message, e.g. the remaining PIN retries.
    public var detail: String?

    public init(code: UInt8, detail: String? = nil) {
        self.init(code: code, name: CTAPStatusCode.name(code), detail: detail)
    }

    public init(code: UInt8, name: String, detail: String? = nil) {
        self.code = code
        self.name = name
        self.detail = detail
    }

    public static let pinInvalid: UInt8 = 0x31
    public static let pinBlocked: UInt8 = 0x32
    public static let pinAuthBlocked: UInt8 = 0x34
    public static let pinNotSet: UInt8 = 0x35
    public static let pinPolicyViolation: UInt8 = 0x37
    public static let notAllowed: UInt8 = 0x30
}

extension CTAPError: LocalizedError {
    public var errorDescription: String? {
        let base = "\(CTAPStatusCode.meaning(code)) (\(name), 0x\(Hex.byte(code)))."
        return detail.map { "\(base) \($0)" } ?? base
    }
}

extension CTAPError: TraceErrorConvertible {
    public var traceError: TraceError {
        TraceError(domain: .ctap, code: "0x\(Hex.byte(code))", name: name, message: errorDescription ?? name)
    }
}
