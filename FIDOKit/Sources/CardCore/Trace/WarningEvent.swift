/// Something worth reporting that did not stop the scenario, e.g. non-canonical CBOR from the card.
public struct WarningEvent: Codable, Sendable, Equatable {
    public var t: Int64
    public var code: TraceWarningCode
    public var message: String

    public init(t: Int64, code: TraceWarningCode, message: String) {
        self.t = t
        self.code = code
        self.message = message
    }
}
