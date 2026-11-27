import FIDOKit
import SwiftUI

/// One run in the History list: scenario, time, card, outcome and the transaction total.
struct HistoryRowView: View {
    let trace: Trace
    let isSelected: Bool

    var body: some View {
        TraceSummaryRowView(
            title: "\(TraceDescription.scenario(trace)) · \(trace.card.label)",
            subtitle: "\(TraceDescription.time(trace)) · \(TraceDescription.outcome(trace))",
            detail: TraceMetrics(trace: trace).sessionTotal.map(TimingFormat.milliseconds) ?? "—",
            isSelected: isSelected
        )
    }
}
