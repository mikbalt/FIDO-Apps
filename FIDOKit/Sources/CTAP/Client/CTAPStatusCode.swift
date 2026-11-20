import CardCore

/// Names of CTAP status bytes, from the study guide §9 table.
///
/// Codes up to `0x0B`, and `0x7F`, carry the `CTAP1_ERR_` prefix; codes from `0x11` on carry `CTAP2_ERR_`.
/// `0xE0–0xEF` are extension-specific and `0xF0–0xFF` vendor-specific.
public enum CTAPStatusCode {
    public static let ok: UInt8 = 0x00

    public static func name(_ code: UInt8) -> String {
        if let name = names[code] { return name }
        switch code {
        case 0xE0...0xEF: return "CTAP2_ERR_EXTENSION_SPECIFIC_0x\(Hex.byte(code))"
        case 0xF0...0xFF: return "CTAP2_ERR_VENDOR_SPECIFIC_0x\(Hex.byte(code))"
        default: return "CTAP_STATUS_0x\(Hex.byte(code))"
        }
    }

    /// A short human-readable meaning for the error message.
    public static func meaning(_ code: UInt8) -> String {
        switch code {
        case 0xE0...0xEF: return "Extension-specific error"
        case 0xF0...0xFF: return "Vendor-specific error"
        default: return meanings[code] ?? "Unknown CTAP status"
        }
    }

    private static let names: [UInt8: String] = [
        0x00: "CTAP2_OK",
        0x01: "CTAP1_ERR_INVALID_COMMAND",
        0x02: "CTAP1_ERR_INVALID_PARAMETER",
        0x03: "CTAP1_ERR_INVALID_LENGTH",
        0x04: "CTAP1_ERR_INVALID_SEQ",
        0x05: "CTAP1_ERR_TIMEOUT",
        0x06: "CTAP1_ERR_CHANNEL_BUSY",
        0x0A: "CTAP1_ERR_LOCK_REQUIRED",
        0x0B: "CTAP1_ERR_INVALID_CHANNEL",
        0x11: "CTAP2_ERR_CBOR_UNEXPECTED_TYPE",
        0x12: "CTAP2_ERR_INVALID_CBOR",
        0x14: "CTAP2_ERR_MISSING_PARAMETER",
        0x15: "CTAP2_ERR_LIMIT_EXCEEDED",
        0x17: "CTAP2_ERR_FP_DATABASE_FULL",
        0x18: "CTAP2_ERR_LARGE_BLOB_STORAGE_FULL",
        0x19: "CTAP2_ERR_CREDENTIAL_EXCLUDED",
        0x21: "CTAP2_ERR_PROCESSING",
        0x22: "CTAP2_ERR_INVALID_CREDENTIAL",
        0x23: "CTAP2_ERR_USER_ACTION_PENDING",
        0x24: "CTAP2_ERR_OPERATION_PENDING",
        0x25: "CTAP2_ERR_NO_OPERATIONS",
        0x26: "CTAP2_ERR_UNSUPPORTED_ALGORITHM",
        0x27: "CTAP2_ERR_OPERATION_DENIED",
        0x28: "CTAP2_ERR_KEY_STORE_FULL",
        0x2B: "CTAP2_ERR_UNSUPPORTED_OPTION",
        0x2C: "CTAP2_ERR_INVALID_OPTION",
        0x2D: "CTAP2_ERR_KEEPALIVE_CANCEL",
        0x2E: "CTAP2_ERR_NO_CREDENTIALS",
        0x2F: "CTAP2_ERR_USER_ACTION_TIMEOUT",
        0x30: "CTAP2_ERR_NOT_ALLOWED",
        0x31: "CTAP2_ERR_PIN_INVALID",
        0x32: "CTAP2_ERR_PIN_BLOCKED",
        0x33: "CTAP2_ERR_PIN_AUTH_INVALID",
        0x34: "CTAP2_ERR_PIN_AUTH_BLOCKED",
        0x35: "CTAP2_ERR_PIN_NOT_SET",
        0x36: "CTAP2_ERR_PUAT_REQUIRED",
        0x37: "CTAP2_ERR_PIN_POLICY_VIOLATION",
        0x39: "CTAP2_ERR_REQUEST_TOO_LARGE",
        0x3A: "CTAP2_ERR_ACTION_TIMEOUT",
        0x3B: "CTAP2_ERR_UP_REQUIRED",
        0x3C: "CTAP2_ERR_UV_BLOCKED",
        0x3D: "CTAP2_ERR_INTEGRITY_FAILURE",
        0x3E: "CTAP2_ERR_INVALID_SUBCOMMAND",
        0x3F: "CTAP2_ERR_UV_INVALID",
        0x40: "CTAP2_ERR_UNAUTHORIZED_PERMISSION",
        0x7F: "CTAP1_ERR_OTHER",
    ]

    private static let meanings: [UInt8: String] = [
        0x00: "Success",
        0x01: "Invalid command",
        0x02: "Invalid parameter",
        0x03: "Invalid length",
        0x04: "Invalid sequence",
        0x05: "Timeout",
        0x06: "Channel busy",
        0x0A: "Lock required",
        0x0B: "Invalid channel",
        0x11: "Unexpected CBOR type",
        0x12: "Invalid CBOR",
        0x14: "Missing parameter",
        0x15: "Limit exceeded",
        0x17: "Fingerprint database full",
        0x18: "Large-blob storage full",
        0x19: "Credential excluded",
        0x21: "Processing",
        0x22: "Invalid credential",
        0x23: "User action pending",
        0x24: "Operation pending",
        0x25: "No operations",
        0x26: "Unsupported algorithm",
        0x27: "Operation denied",
        0x28: "Key store full",
        0x2B: "Unsupported option",
        0x2C: "Invalid option",
        0x2D: "Keep-alive cancel",
        0x2E: "No credentials",
        0x2F: "User action timeout",
        0x30: "Not allowed",
        0x31: "The PIN is wrong",
        0x32: "The PIN is blocked",
        0x33: "PIN auth invalid",
        0x34: "PIN auth blocked",
        0x35: "No PIN is set",
        0x36: "A pinUvAuthToken is required",
        0x37: "The PIN does not meet the card's policy",
        0x39: "Request too large",
        0x3A: "Action timeout",
        0x3B: "User presence required",
        0x3C: "User verification blocked",
        0x3D: "Integrity failure",
        0x3E: "Invalid subcommand",
        0x3F: "User verification invalid",
        0x40: "Unauthorized permission",
        0x7F: "Other error",
    ]
}
