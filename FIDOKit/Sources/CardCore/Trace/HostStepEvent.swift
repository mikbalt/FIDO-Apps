/// App-side work inside a scenario, e.g. `CBOR_ENCODE`, `CBOR_DECODE`, `PIN_PROTOCOL`, `RP_VERIFY`.
public struct HostStepEvent: Codable, Sendable, Equatable {
    public var label: String
    public var tStart: Int64
    public var tEnd: Int64

    public init(label: String, tStart: Int64, tEnd: Int64) {
        self.label = label
        self.tStart = tStart
        self.tEnd = tEnd
    }

    public var duration: Int64 { tEnd - tStart }
}
