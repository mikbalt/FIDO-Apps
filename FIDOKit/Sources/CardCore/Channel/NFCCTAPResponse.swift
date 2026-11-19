/// The result of an NFCCTAP_MSG sent with `ISO7816Channel.sendNFCCTAP`.
public struct NFCCTAPResponse: Sendable, Equatable {
    /// The complete response: CTAP status byte plus CBOR, and the final SW.
    public var response: ResponseAPDU
    /// The card rejected P1 = `80` and the command was resent with P1 = `00`. Use P1 = `00` from now on.
    public var usedP1Fallback: Bool

    public init(response: ResponseAPDU, usedP1Fallback: Bool) {
        self.response = response
        self.usedP1Fallback = usedP1Fallback
    }
}
