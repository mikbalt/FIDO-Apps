import os

/// Records `onCardReset` calls.
final class ResetLog: Sendable {
    private let calls = OSAllocatedUnfairLock<[String]>(initialState: [])

    var labels: [String] { calls.withLock { $0 } }

    var record: @Sendable (String) -> Void {
        { label in self.calls.withLock { $0.append(label) } }
    }
}
