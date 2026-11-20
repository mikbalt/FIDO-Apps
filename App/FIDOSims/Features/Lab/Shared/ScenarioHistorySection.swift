import FIDOKit
import SwiftUI

/// The last runs, newest first. Selecting one shows its results.
struct ScenarioHistorySection: View {
    let model: ScenarioRunModel

    var body: some View {
        Section("History (last \(ScenarioRunModel.historyLimit))") {
            ForEach(model.history) { trace in
                Button {
                    model.selectedTraceID = trace.id
                } label: {
                    TraceSummaryRowView(
                        title: trace.card.label,
                        subtitle: "\(trace.createdAt.formatted(date: .omitted, time: .standard)) · "
                            + (trace.outcome.map { $0.error?.name ?? $0.status.rawValue.capitalized }
                                ?? trace.endReason?.displayName ?? "In progress"),
                        detail: TraceMetrics(trace: trace).sessionTotal.map(TimingFormat.milliseconds) ?? "—",
                        isSelected: trace.id == model.selectedTraceID
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
