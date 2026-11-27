import FIDOKit
import Foundation
import Testing
@testable import FIDOSims

@MainActor
@Suite("HistoryViewModel")
struct HistoryViewModelTests {
    private func store(with traces: [Trace]) throws -> TraceStore {
        let store = TraceStore(directory: FileManager.default.temporaryDirectory.appending(path: "fidosims-hist-\(UUID().uuidString)"))
        for (index, var trace) in traces.enumerated() {
            // Whole-second timestamps: space them out so the order is the index order, oldest first.
            trace.createdAt = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 10)
            try store.save(trace)
        }
        return store
    }

    @Test("Lists saved runs newest first; nothing is selected until a run is opened")
    func list() throws {
        let a = try TestSupport.trace(), b = try TestSupport.trace()
        let model = HistoryViewModel(store: try store(with: [a, b]))
        #expect(model.traces.map(\.id) == [b.id, a.id])
        #expect(model.selectedTrace == nil)
        #expect(!model.isViewingOlderRun)
    }

    @Test("Opening an older run sets isViewingOlderRun; Back to latest opens the newest")
    func olderAndLatest() throws {
        let a = try TestSupport.trace(), b = try TestSupport.trace()
        let model = HistoryViewModel(store: try store(with: [a, b]))
        model.select(a.id)
        #expect(model.selectedTrace?.id == a.id)
        #expect(model.selectedMetrics != nil)
        #expect(model.isViewingOlderRun)

        model.showLatest()
        #expect(model.selectedTrace?.id == b.id)
        #expect(!model.isViewingOlderRun)
    }

    @Test("A run can be opened straight away, and delete removes it from the list and the disk")
    func openAndDelete() throws {
        let a = try TestSupport.trace(), b = try TestSupport.trace()
        let history = try store(with: [a, b])
        let model = HistoryViewModel(store: history, selecting: a.id)
        #expect(model.selectedTrace?.id == a.id)

        model.delete(a)
        #expect(model.traces.map(\.id) == [b.id])
        #expect(model.selectedTrace == nil)
        #expect(history.list().map(\.id) == [b.id])
    }

    @Test("reload picks up runs saved later and keeps the open run open")
    func reload() throws {
        let a = try TestSupport.trace()
        let history = try store(with: [a])
        let model = HistoryViewModel(store: history, selecting: a.id)
        var later = try TestSupport.trace()
        later.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        try history.save(later)
        model.reload()
        #expect(model.traces.count == 2)
        #expect(model.selectedTrace?.id == a.id)
        #expect(model.isViewingOlderRun)
    }

    @Test("Scenario names for the list")
    func names() throws {
        var trace = try TestSupport.trace()
        trace.scenario = .register
        #expect(TraceDescription.scenario(trace) == "Register")
        trace.scenario = .unknown("x")
        #expect(TraceDescription.scenario(trace) == "x")
    }
}
