public struct TraceOptions: Codable, Sendable, Equatable {
    public var lengthForm: LengthForm
    public var getResponseSupported: Bool

    public init(lengthForm: LengthForm = .short, getResponseSupported: Bool = false) {
        self.lengthForm = lengthForm
        self.getResponseSupported = getResponseSupported
    }
}
