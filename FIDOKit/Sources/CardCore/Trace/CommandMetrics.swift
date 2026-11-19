/// Timing of one logical command: the sum of its physical exchanges.
public struct CommandMetrics: Sendable, Equatable, Identifiable {
    public var commandIndex: Int
    public var label: String
    /// Σ RTT of the command's physical exchanges, in nanoseconds.
    public var rtt: Int64
    public var exchangeCount: Int

    public init(commandIndex: Int, label: String, rtt: Int64, exchangeCount: Int) {
        self.commandIndex = commandIndex
        self.label = label
        self.rtt = rtt
        self.exchangeCount = exchangeCount
    }

    public var id: Int { commandIndex }
}
