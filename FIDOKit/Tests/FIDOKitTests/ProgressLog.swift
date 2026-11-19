import FIDOKit
import Foundation

/// Collects diagnostics progress callbacks, which may arrive from any task.
actor ProgressLog {
    private(set) var events: [DiagnosticsProgress] = []

    func append(_ event: DiagnosticsProgress) {
        events.append(event)
    }

    nonisolated func callback() -> @Sendable (DiagnosticsProgress) -> Void {
        { event in Task { await self.append(event) } }
    }
}
