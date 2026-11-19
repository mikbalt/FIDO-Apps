/// Placeholder shown for the bytes of sensitive exchanges in Safe mode and in redacted text exports.
/// Never written to JSON: see `ExchangeEvent`.
public enum Redaction {
    public static func placeholder(byteCount: Int) -> String {
        "<redacted \(byteCount) bytes>"
    }
}
