import FIDOKit
import SwiftUI

/// The common layout of a Lab screen: its setup, then run, results and timing.
struct ScenarioScreen<Setup: View, Results: View>: View {
    let title: String
    @Bindable var model: ScenarioRunModel
    let runTitle: String
    let canRun: Bool
    let run: () -> Void
    @ViewBuilder let setup: () -> Setup
    /// Extra sections between Run and the timing, e.g. the RP checks.
    @ViewBuilder let results: () -> Results

    init(
        title: String, model: ScenarioRunModel, runTitle: String, canRun: Bool, run: @escaping () -> Void,
        @ViewBuilder setup: @escaping () -> Setup, @ViewBuilder results: @escaping () -> Results
    ) {
        self.title = title
        self.model = model
        self.runTitle = runTitle
        self.canRun = canRun
        self.run = run
        self.setup = setup
        self.results = results
    }

    var body: some View {
        List {
            setup()
                .disabled(model.isRunning)
            ScenarioRunSection(model: model, runTitle: runTitle, canRun: canRun, run: run)
            results()
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

extension ScenarioScreen where Results == EmptyView {
    init(
        title: String, model: ScenarioRunModel, runTitle: String, canRun: Bool, run: @escaping () -> Void,
        @ViewBuilder setup: @escaping () -> Setup
    ) {
        self.init(title: title, model: model, runTitle: runTitle, canRun: canRun, run: run, setup: setup, results: { EmptyView() })
    }
}
