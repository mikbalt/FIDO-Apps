import FIDOKit
import SwiftUI

/// Run and Cancel, with the live state of the current run, or the selected History trace.
struct DiagnosticsRunSection: View {
    let model: DiagnosticsViewModel

    var body: some View {
        Section("Run") {
            if model.isViewingHistory, let trace = model.selectedTrace {
                historyStatus(for: trace)
                Button("Back to latest", systemImage: "arrow.uturn.backward") {
                    model.showLatest()
                }
            } else {
                RunStatusView(
                    title: title,
                    systemImage: systemImage,
                    tint: tint,
                    note: note,
                    isActive: model.state.isRunning,
                    startedAt: model.runStartedAt,
                    endedAt: model.runEndedAt
                )
            }

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

    /// The outcome, time, transport and card of a History trace. No elapsed time: that belongs to the live run.
    private func historyStatus(for trace: Trace) -> some View {
        let reason = trace.endReason
        let time = trace.createdAt.formatted(date: .omitted, time: .standard)
        return RunStatusView(
            title: "History · \(time)",
            systemImage: reason.map { Self.systemImage(for: $0) } ?? "circle.dotted",
            tint: reason.map { Self.tint(for: $0) } ?? .secondary,
            note: [reason?.displayName ?? "In progress", trace.transport.rawValue, trace.card.label]
                .joined(separator: " · "),
            isActive: false,
            startedAt: nil,
            endedAt: nil
        )
    }

    private static func systemImage(for reason: SessionEndReason) -> String {
        switch reason {
        case .completed: "checkmark.circle.fill"
        case .cancelled, .userCancelled: "stop.circle"
        default: "exclamationmark.circle.fill"
        }
    }

    private static func tint(for reason: SessionEndReason) -> Color {
        switch reason {
        case .completed: .green
        case .cancelled, .userCancelled: .secondary
        default: .orange
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
