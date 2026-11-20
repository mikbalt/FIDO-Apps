/// The result of a `FIDOSimulator` scenario. Scenarios never throw. [CONTRACT]
public struct ScenarioResult<Value: Sendable>: Sendable {
    public let value: Value?
    public let error: FIDOSimError?
    public let trace: Trace          // always present, complete up to the failure point

    public init(value: Value?, error: FIDOSimError?, trace: Trace) {
        self.value = value
        self.error = error
        self.trace = trace
    }
}
