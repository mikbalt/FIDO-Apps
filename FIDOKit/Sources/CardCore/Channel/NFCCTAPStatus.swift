/// The status byte of an NFCCTAP status update (SW `9100`).
public enum NFCCTAPStatus: Equatable, Sendable {
    /// `01`: the authenticator is still processing.
    case processing
    /// `02`: user presence is needed, e.g. a touch on the card.
    case userPresenceNeeded
    /// Any other byte, or a missing one.
    case other(UInt8?)

    public init(statusByte: UInt8?) {
        switch statusByte {
        case 0x01: self = .processing
        case 0x02: self = .userPresenceNeeded
        default: self = .other(statusByte)
        }
    }

    /// The trace form: `PROCESSING`, `UPNEEDED`, the byte in hex (e.g. `05`) or `NONE` when missing.
    public var traceValue: String {
        switch self {
        case .processing: "PROCESSING"
        case .userPresenceNeeded: "UPNEEDED"
        case let .other(byte?): Hex.byte(byte)
        case .other(nil): "NONE"
        }
    }

    public init(traceValue: String) {
        switch traceValue {
        case "PROCESSING": self = .processing
        case "UPNEEDED": self = .userPresenceNeeded
        default:
            let bytes = try? Hex.parse(traceValue)
            self = .other(bytes?.count == 1 ? bytes?.first : nil)
        }
    }
}
