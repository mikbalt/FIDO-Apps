import FIDOKit
import os

/// Collects scenario steps synchronously, in the order they are reported.
final class ProgressLog: Sendable {
    private let steps = OSAllocatedUnfairLock<[ScenarioStep]>(initialState: [])

    var events: [ScenarioStep] { steps.withLock { $0 } }

    func callback() -> @Sendable (ScenarioStep) -> Void {
        { step in self.steps.withLock { $0.append(step) } }
    }
}
