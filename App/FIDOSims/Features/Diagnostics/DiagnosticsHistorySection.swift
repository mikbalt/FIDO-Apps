import FIDOKit
import SwiftUI

/// The last runs, newest first. Selecting one shows its results.
struct DiagnosticsHistorySection: View {
    let model: DiagnosticsViewModel

    var body: some View {
        Section("History (last \(DiagnosticsViewModel.historyLimit))") {
            ForEach(model.history) { trace in
                Button {
                    model.selectedTraceID = trace.id
                } label: {
                    TraceSummaryRowView(
                        title: trace.card.label,
                        subtitle: "\(trace.createdAt.formatted(date: .omitted, time: .standard)) · "
                            + (trace.endReason?.displayName ?? "In progress"),
                        detail: TraceMetrics(trace: trace).sessionTotal.map(TimingFormat.milliseconds) ?? "—",
                        isSelected: trace.id == model.selectedTraceID
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
