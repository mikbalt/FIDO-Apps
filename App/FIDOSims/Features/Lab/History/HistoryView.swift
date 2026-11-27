import FIDOKit
import SwiftUI

/// Lab › History. The status row names the run on screen ("History · <time>"), and "Back to latest" returns
/// to the newest run, so the numbers are never ambiguous about which run they belong to.
struct HistoryView: View {
    @Bindable var model: HistoryViewModel

    var body: some View {
        List {
            if let error = model.error {
                Text(error).foregroundStyle(.red)
            }
            if let trace = model.selectedTrace, let metrics = model.selectedMetrics {
                Section("Run") {
                    RunStatusView(
                        title: "History · \(trace.createdAt.formatted(date: .omitted, time: .standard))",
                        systemImage: ScenarioRunSection.systemImage(for: trace.outcome?.status),
                        tint: ScenarioRunSection.tint(for: trace.outcome?.status),
                        note: [TraceDescription.scenario(trace), TraceDescription.outcome(trace), trace.transport.rawValue, trace.card.label]
                            .joined(separator: " · "),
                        isActive: false, startedAt: nil, endedAt: nil
                    )
                    if model.isViewingOlderRun {
                        Button("Back to latest", systemImage: "arrow.uturn.backward") {
                            model.showLatest()
                        }
                    }
                }
                TraceResultSections(displayMode: $model.displayMode, trace: trace, metrics: metrics)
            }
            Section("Runs") {
                if model.traces.isEmpty {
                    Text("No runs yet.").foregroundStyle(.secondary)
                }
                ForEach(model.traces) { trace in
                    Button {
                        model.select(trace.id)
                    } label: {
                        HistoryRowView(trace: trace, isSelected: trace.id == model.selectedTrace?.id)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            model.delete(trace)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if let trace = model.selectedTrace {
                ToolbarItem(placement: .primaryAction) {
                    TraceShareMenu(trace: trace)
                }
            }
        }
        .onAppear { model.reload() }
    }
}
