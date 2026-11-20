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
}
