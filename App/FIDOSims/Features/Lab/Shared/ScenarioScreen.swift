import FIDOKit
import SwiftUI

/// The common layout of a Lab screen: its setup, then run, results and history.
struct ScenarioScreen<Setup: View>: View {
    let title: String
    let model: ScenarioRunModel
    let runTitle: String
    let canRun: Bool
    let run: () -> Void
    @ViewBuilder let setup: () -> Setup

    var body: some View {
        List {
            setup()
                .disabled(model.isRunning)
            ScenarioRunSection(model: model, runTitle: runTitle, canRun: canRun, run: run)
            if let trace = model.selectedTrace, let metrics = model.selectedMetrics {
                TraceResultSections(model: model, trace: trace, metrics: metrics)
            }
            if !model.history.isEmpty {
                ScenarioHistorySection(model: model)
            }
        }
        .navigationTitle(title)
        .toolbar {
            if let trace = model.selectedTrace {
                ToolbarItem(placement: .primaryAction) {
                    TraceShareMenu(trace: trace)
                }
            }
        }
    }
}
