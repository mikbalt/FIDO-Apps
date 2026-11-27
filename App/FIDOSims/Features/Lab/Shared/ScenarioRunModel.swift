import FIDOKit
import Foundation
import Observation

/// Runs one `FIDOSimulator` scenario at a time for a Lab screen: live steps, elapsed time and the trace of
/// the latest run. Past runs are in Lab › History (saved by the facade), not here.
@MainActor
@Observable
final class ScenarioRunModel {
    /// Runs the scenario, reporting steps, and returns its trace and error.
    typealias Operation = @Sendable (
        _ progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> (trace: Trace, error: FIDOSimError?)

    // MARK: Run

    private(set) var steps: [ScenarioStep] = []
    private(set) var isRunning = false
    private(set) var runStartedAt: Date?
    private(set) var runEndedAt: Date?
    private(set) var lastError: FIDOSimError?
    var displayMode: ExchangeDisplayMode = .safe

    // MARK: Results

    /// The trace of the most recent run; `nil` while a run is in progress.
    private(set) var latestTrace: Trace?
    private(set) var latestMetrics: TraceMetrics?

    private var runTask: Task<Void, Never>?

    /// The outcome of the most recent run, once it finished.
    var latestOutcome: TraceOutcome? {
        isRunning ? nil : latestTrace?.outcome
    }

    /// - Parameter onSuccess: Runs on the main actor after a successful run, e.g. to store the PIN.
    func run(_ operation: @escaping Operation, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard !isRunning else { return }
        // The previous results must not stay on screen next to the new run's state.
        latestTrace = nil
        latestMetrics = nil
        steps = []
        lastError = nil
        runStartedAt = .now
        runEndedAt = nil
        isRunning = true

        // Steps arrive off the main actor; a stream keeps them in order.
        let (stepUpdates, stepContinuation) = AsyncStream.makeStream(of: ScenarioStep.self)
        Task {
            for await step in stepUpdates {
                steps.append(step)
            }
        }

        runTask = Task {
            let (trace, error) = await operation { stepContinuation.yield($0) }
            stepContinuation.finish()
            finish(trace: trace, error: error)
            if error == nil, trace.outcome?.status == .success {
                onSuccess()
            }
        }
    }

    func cancel() {
        runTask?.cancel()
    }

    private func finish(trace: Trace, error: FIDOSimError?) {
        runEndedAt = .now
        isRunning = false
        lastError = error
        runTask = nil
        latestTrace = trace
        latestMetrics = TraceMetrics(trace: trace)
    }
}
