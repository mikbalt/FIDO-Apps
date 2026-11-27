import FIDOKit
import SwiftUI

/// The common layout of a Lab screen: its setup, then run, results and history.
struct ScenarioScreen<Setup: View>: View {
    let title: String
    @Bindable var model: ScenarioRunModel
    let runTitle: String
    let canRun: Bool
    let run: () -> Void
    @ViewBuilder let setup: () -> Setup

    var body: some View {
        List {
            setup()
                .disabled(model.isRunning)
            ScenarioRunSection(model: model, runTitle: runTitle, canRun: canRun, run: run)
            if let trace = model.latestTrace, let metrics = model.latestMetrics {
                TraceResultSections(displayMode: $model.displayMode, trace: trace, metrics: metrics)
            }
        }
        .navigationTitle(title)
        .toolbar {
            if let trace = model.latestTrace {
                ToolbarItem(placement: .primaryAction) {
                    TraceShareMenu(trace: trace)
                }
            }
        }
    }
}
