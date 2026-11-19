import Foundation

extension CommandAPDU {
    /// SELECT the FIDO applet: `00 A4 04 00 08 A0 00 00 06 47 2F 00 01 00`.
    public static let selectFIDO = CommandAPDU(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00, data: FIDOApplet.aid, le: 256)

    /// NFCCTAP_GETRESPONSE: `80 11 00 00 00`.
    public static let nfcctapGetResponse = CommandAPDU(cla: 0x80, ins: 0x11, p1: 0x00, p2: 0x00, le: 256)

    /// ISO 7816 GET RESPONSE: `00 C0 00 00 xx`.
    public static func getResponse(le: Int) -> CommandAPDU {
        CommandAPDU(cla: 0x00, ins: 0xC0, p1: 0x00, p2: 0x00, le: le)
    }
}
