extension Duration {
    /// Whole nanoseconds, truncating sub-nanosecond precision.
    var wholeNanoseconds: Int64 {
        let (seconds, attoseconds) = components
        return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
    }
}
