import FIDOKit
import Foundation
import Testing
@testable import FIDOSims

@MainActor
@Suite("ScenarioRunModel")
struct ScenarioRunModelTests {
    private func run(_ runner: ScenarioRunModel, outcome: TraceOutcome = .success) async throws -> Trace {
        let trace = try TestSupport.trace(outcome: outcome)
        runner.run { _ in (trace, nil) }
        await TestSupport.waitUntilIdle(runner)
        return trace
    }

    @Test("The latest trace is selected when a run ends")
    func selectsLatest() async throws {
        let runner = ScenarioRunModel()
        let trace = try await run(runner)
        #expect(!runner.isRunning)
        #expect(runner.latestTraceID == trace.id)
        #expect(runner.selectedTraceID == trace.id)
        #expect(runner.selectedTrace?.id == trace.id)
        #expect(runner.selectedMetrics != nil)
        #expect(runner.latestOutcome == .success)
        #expect(!runner.isViewingHistory)
    }

    @Test("A new run clears the previous results while it is in progress")
    func clearsPreviousResults() async throws {
        let runner = ScenarioRunModel()
        let first = try await run(runner)
        let gate = Gate()
        let second = try TestSupport.trace()
        runner.run { progress in
            progress(.waitingForCard)
            await gate.wait()
            return (second, nil)
        }
        #expect(runner.isRunning)
        #expect(runner.selectedTrace == nil)
        #expect(runner.selectedMetrics == nil)
        #expect(runner.latestTraceID == nil)
        #expect(runner.latestOutcome == nil)
        #expect(runner.lastError == nil)
        #expect(!runner.isViewingHistory)
        // The previous run stays reachable through History.
        #expect(runner.history.map(\.id) == [first.id])

        await gate.open()
        await TestSupport.waitUntilIdle(runner)
        #expect(runner.history.map(\.id) == [second.id, first.id])
        #expect(runner.selectedTraceID == second.id)
        #expect(runner.steps == [.waitingForCard])
    }

    @Test("Selecting a History trace sets isViewingHistory; showLatest returns to the latest run")
    func historyAndShowLatest() async throws {
        let runner = ScenarioRunModel()
        let first = try await run(runner)
        let second = try await run(runner, outcome: .cancelled)
        #expect(!runner.isViewingHistory)

        runner.selectedTraceID = first.id
        #expect(runner.isViewingHistory)
        #expect(runner.selectedTrace?.id == first.id)
        // The latest outcome belongs to the latest run, not to the History trace on screen.
        #expect(runner.latestOutcome == .cancelled)

        runner.showLatest()
        #expect(!runner.isViewingHistory)
        #expect(runner.selectedTraceID == second.id)
    }

    @Test("The history keeps the last 10 traces, newest first")
    func historyLimit() async throws {
        let runner = ScenarioRunModel()
        var ids: [Trace.ID] = []
        for _ in 0..<(ScenarioRunModel.historyLimit + 3) {
            ids.append(try await run(runner).id)
        }
        #expect(ScenarioRunModel.historyLimit == 10)
        #expect(runner.history.count == 10)
        #expect(runner.history.map(\.id) == Array(ids.reversed().prefix(10)))
    }

    @Test("onSuccess runs after a successful run only")
    func onSuccessGate() async throws {
        let runner = ScenarioRunModel()
        var calls = 0
        for outcome in [TraceOutcome.success, .cancelled] {
            let trace = try TestSupport.trace(outcome: outcome)
            runner.run({ _ in (trace, nil) }, onSuccess: { calls += 1 })
            await TestSupport.waitUntilIdle(runner)
        }
        #expect(calls == 1)
    }
}
