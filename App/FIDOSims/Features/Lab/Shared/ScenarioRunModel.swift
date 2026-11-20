import FIDOKit
import Foundation
import Observation

/// Runs one `FIDOSimulator` scenario at a time for a Lab screen: live steps, elapsed time, the last 10
/// traces and which one is shown.
@MainActor
@Observable
final class ScenarioRunModel {
    static let historyLimit = 10

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

    private(set) var history: [Trace] = [] {
        didSet { updateSelection() }
    }
    var selectedTraceID: Trace.ID? {
        didSet { updateSelection() }
    }
    /// The trace of the most recent run; `nil` while a run is in progress.
    private(set) var latestTraceID: Trace.ID?
    /// Cached from `history` and `selectedTraceID`, so result views don't depend on the whole history.
    private(set) var selectedTrace: Trace?
    private(set) var selectedMetrics: TraceMetrics?

    private var runTask: Task<Void, Never>?

    /// The results on screen belong to a History trace, not to the most recent run.
    var isViewingHistory: Bool {
        selectedTrace != nil && selectedTraceID != latestTraceID
    }

    /// The outcome of the most recent run, once it finished.
    var latestOutcome: TraceOutcome? {
        guard !isRunning else { return nil }
        return history.first { $0.id == latestTraceID }?.outcome
    }

    /// - Parameter onSuccess: Runs on the main actor after a successful run, e.g. to store the PIN.
    func run(_ operation: @escaping Operation, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard !isRunning else { return }
        // The previous results must not stay on screen next to the new run's state.
        latestTraceID = nil
        selectedTraceID = nil
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

    /// Leaves History and shows the most recent run again.
    func showLatest() {
        selectedTraceID = latestTraceID
    }

    private func finish(trace: Trace, error: FIDOSimError?) {
        runEndedAt = .now
        isRunning = false
        lastError = error
        runTask = nil
        history = Array(([trace] + history).prefix(Self.historyLimit))
        latestTraceID = trace.id
        selectedTraceID = trace.id
    }

    private func updateSelection() {
        let trace = history.first { $0.id == selectedTraceID }
        selectedTrace = trace
        selectedMetrics = trace.map(TraceMetrics.init(trace:))
    }
}
