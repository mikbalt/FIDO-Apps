/// Formats nanosecond durations for display.
public enum TimingFormat {
    /// Milliseconds with exactly 3 decimals, e.g. `12.400 ms`. Rounds half away from zero to the microsecond.
    public static func milliseconds(_ nanoseconds: Int64) -> String {
        let sign = nanoseconds < 0 ? "-" : ""
        let magnitude = nanoseconds.magnitude
        let microseconds = (magnitude + 500) / 1_000
        let whole = microseconds / 1_000
        let fraction = microseconds % 1_000
        let padded = String(repeating: "0", count: 3 - String(fraction).count) + String(fraction)
        return "\(sign)\(whole).\(padded) ms"
    }
}
