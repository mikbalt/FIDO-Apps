import Foundation

/// Constants of the FIDO NFC applet (CTAP 2.1 §11.3).
public enum FIDOApplet {
    /// `A0000006472F0001`.
    public static let aid = Data([0xA0, 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01])

    /// Version strings returned by SELECT.
    public static let knownVersions: Set<String> = ["U2F_V2", "FIDO_2_0"]
}
