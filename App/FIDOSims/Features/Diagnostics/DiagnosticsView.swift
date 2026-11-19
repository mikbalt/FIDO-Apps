import FIDOKit
import SwiftUI

/// Temporary engineering screen: run SELECT + GetInfo and inspect the timing of every APDU.
struct DiagnosticsView: View {
    let model: DiagnosticsViewModel

    var body: some View {
        NavigationStack {
            List {
                DiagnosticsSetupSection(model: model)
                DiagnosticsRunSection(model: model)
                if let trace = model.selectedTrace, let metrics = model.selectedMetrics {
                    DiagnosticsResultSections(model: model, trace: trace, metrics: metrics)
                }
                if !model.history.isEmpty {
                    DiagnosticsHistorySection(model: model)
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                if let trace = model.selectedTrace {
                    ToolbarItem(placement: .primaryAction) {
                        TraceShareMenu(trace: trace)
                    }
                }
            }
        }
    }
}

#Preview {
    DiagnosticsView(model: AppContainer().makeDiagnosticsViewModel())
}
