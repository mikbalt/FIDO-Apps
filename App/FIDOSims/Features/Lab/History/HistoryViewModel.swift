import FIDOKit
import Foundation
import Observation

/// Lab › History: every saved run, newest first, and the one being looked at.
@MainActor
@Observable
final class HistoryViewModel {
    private(set) var traces: [Trace] = []
    private(set) var selectedTrace: Trace?
    private(set) var selectedMetrics: TraceMetrics?
    private(set) var error: String?
    var displayMode: ExchangeDisplayMode = .safe

    private let store: TraceStore

    /// - Parameter selecting: A run to open straight away, e.g. from a result screen's "View log".
    init(store: TraceStore, selecting id: Trace.ID? = nil) {
        self.store = store
        reload()
        select(id)
    }

    var latestID: Trace.ID? { traces.first?.id }

    /// A run older than the newest one is on screen: the status row says so and offers "Back to latest".
    var isViewingOlderRun: Bool {
        selectedTrace != nil && selectedTrace?.id != latestID
    }

    /// Reads the files again. The open run stays open if it still exists.
    func reload() {
        traces = store.list()
        select(selectedTrace?.id)
    }

    func select(_ id: Trace.ID?) {
        selectedTrace = traces.first { $0.id == id }
        selectedMetrics = selectedTrace.map(TraceMetrics.init(trace:))
    }

    func showLatest() {
        select(latestID)
    }

    func delete(_ trace: Trace) {
        do {
            try store.delete(id: trace.id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        reload()
    }
}
