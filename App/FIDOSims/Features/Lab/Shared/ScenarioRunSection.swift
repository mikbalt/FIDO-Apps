import FIDOKit
import SwiftUI

/// Run and Cancel, the live step list and elapsed time.
struct ScenarioRunSection: View {
    let model: ScenarioRunModel
    let runTitle: String
    let canRun: Bool
    let run: () -> Void

    var body: some View {
        Section("Run") {
            RunStatusView(
                title: title, systemImage: systemImage, tint: tint, note: model.lastError?.message,
                isActive: model.isRunning, startedAt: model.runStartedAt, endedAt: model.runEndedAt
            )
            if !model.steps.isEmpty {
                StepListView(steps: model.steps, isRunning: model.isRunning)
            }

            if model.isRunning {
                Button("Cancel", systemImage: "xmark.circle", role: .destructive) {
                    model.cancel()
                }
            } else {
                Button(runTitle, systemImage: "play.fill", action: run)
                    .disabled(!canRun)
                    // List rows keep the tint when disabled; grey it out so it does not read as tappable.
                    .foregroundStyle(canRun ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
    }

    private var title: String {
        if model.isRunning {
            return model.steps.last.map(StepListView.title) ?? "Starting…"
        }
        switch model.latestOutcome?.status {
        case .success: return "Completed"
        case .cancelled: return "Cancelled"
        case .failure: return "Failed: \(model.lastError?.name ?? "error")"
        case nil: return "Ready"
        }
    }

    private var systemImage: String {
        Self.systemImage(for: model.latestOutcome?.status)
    }

    private var tint: Color {
        Self.tint(for: model.latestOutcome?.status)
    }

    static func systemImage(for status: TraceOutcome.Status?) -> String {
        switch status {
        case .success: "checkmark.circle.fill"
        case .cancelled: "stop.circle"
        case .failure: "xmark.octagon.fill"
        case nil: "circle"
        }
    }

    static func tint(for status: TraceOutcome.Status?) -> Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .cancelled, nil: .secondary
        }
    }
}
