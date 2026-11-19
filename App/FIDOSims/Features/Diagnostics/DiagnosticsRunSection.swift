import FIDOKit
import SwiftUI

/// Run and Cancel, with the live state of the current run.
struct DiagnosticsRunSection: View {
    let model: DiagnosticsViewModel

    var body: some View {
        Section("Run") {
            RunStatusView(
                title: title,
                systemImage: systemImage,
                tint: tint,
                note: note,
                isActive: model.state.isRunning,
                startedAt: model.runStartedAt,
                endedAt: model.runEndedAt
            )

            if model.state.isRunning {
                Button("Cancel", systemImage: "xmark.circle", role: .destructive) {
                    model.cancel()
                }
            } else {
                Button("Run SELECT + GetInfo", systemImage: "play.fill") {
                    model.run()
                }
                .disabled(!model.canRun)
            }
        }
    }

    private var title: String {
        switch model.state {
        case .idle: "Ready"
        case .waitingForCard: "Waiting for card…"
        case let .exchanging(label): label.isEmpty ? "Card connected" : "Exchanging \(label)…"
        case let .done(reason): "Done: \(reason.displayName)"
        case .cancelled: "Cancelled"
        case .failed: "Failed"
        }
    }

    private var note: String? {
        switch model.state {
        case let .failed(message): message
        default: model.statusNote
        }
    }

    private var systemImage: String {
        switch model.state {
        case .idle: "circle"
        case let .done(reason): reason == .completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        case .cancelled: "stop.circle"
        case .failed: "xmark.octagon.fill"
        case .waitingForCard, .exchanging: "circle.dotted"
        }
    }

    private var tint: Color {
        switch model.state {
        case let .done(reason): reason == .completed ? .green : .orange
        case .failed: .red
        default: .secondary
        }
    }
}
