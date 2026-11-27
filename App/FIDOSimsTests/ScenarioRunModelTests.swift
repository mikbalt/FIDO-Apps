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

    @Test("The latest trace and its metrics are available when a run ends")
    func latest() async throws {
        let runner = ScenarioRunModel()
        let trace = try await run(runner)
        #expect(!runner.isRunning)
        #expect(runner.latestTrace?.id == trace.id)
        #expect(runner.latestMetrics != nil)
        #expect(runner.latestOutcome == .success)
    }

    @Test("A new run clears the previous results while it is in progress")
    func clearsPreviousResults() async throws {
        let runner = ScenarioRunModel()
        _ = try await run(runner)
        let gate = Gate()
        let second = try TestSupport.trace()
        runner.run { progress in
            progress(.waitingForCard)
            await gate.wait()
            return (second, nil)
        }
        #expect(runner.isRunning)
        #expect(runner.latestTrace == nil)
        #expect(runner.latestMetrics == nil)
        #expect(runner.latestOutcome == nil)
        #expect(runner.lastError == nil)

        await gate.open()
        await TestSupport.waitUntilIdle(runner)
        #expect(runner.latestTrace?.id == second.id)
        #expect(runner.steps == [.waitingForCard])
    }

    @Test("The latest outcome is that of the latest run")
    func latestOutcome() async throws {
        let runner = ScenarioRunModel()
        _ = try await run(runner)
        _ = try await run(runner, outcome: .cancelled)
        #expect(runner.latestOutcome == .cancelled)
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
