/// Every canonical-form violation found while decoding. Empty for canonical input.
public struct CanonicalityReport: Hashable, Sendable {
    public var violations: [CanonicalityViolation]

    public init(violations: [CanonicalityViolation] = []) {
        self.violations = violations
    }

    public var isCanonical: Bool { violations.isEmpty }
}
