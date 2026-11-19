import FIDOKit
import SwiftUI

/// Timing tiles and the exchange list for the selected trace.
struct DiagnosticsResultSections: View {
    @Bindable var model: DiagnosticsViewModel
    let trace: Trace
    let metrics: TraceMetrics

    var body: some View {
        Section("Timing") {
            MetricTilesView(metrics: metrics)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }

        Section {
            TraceListView(exchanges: trace.exchanges, hidesSensitive: model.displayMode.hidesSensitive)
        } header: {
            HStack {
                Text("Exchanges")
                Spacer()
                Picker("Display", selection: $model.displayMode) {
                    ForEach(ExchangeDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        } footer: {
            Text("\(trace.card.label) · \(trace.transport.rawValue) · \(trace.device.model) \(trace.device.os)")
        }
    }
}
