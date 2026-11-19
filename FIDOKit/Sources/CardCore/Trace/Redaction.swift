/// Placeholder used for the bytes of sensitive exchanges in Safe mode and redacted exports.
public enum Redaction {
    public static func placeholder(byteCount: Int) -> String {
        "<redacted \(byteCount) bytes>"
    }

    /// Returns the byte count if `string` is a placeholder.
    static func byteCount(fromPlaceholder string: String) -> Int? {
        guard string.hasPrefix("<redacted "), string.hasSuffix(" bytes>") else { return nil }
        return Int(string.dropFirst("<redacted ".count).dropLast(" bytes>".count))
    }
}
