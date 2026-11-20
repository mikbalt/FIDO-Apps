import FIDOKit
import SwiftUI

/// The steps of a scenario so far. The last one spins while the scenario runs.
struct StepListView: View {
    let steps: [ScenarioStep]
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, step in
                HStack(spacing: 8) {
                    icon(step, isCurrent: isRunning && offset == steps.count - 1)
                        .frame(width: 18)
                    Text(Self.title(step))
                        .font(.caption.monospaced())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func icon(_ step: ScenarioStep, isCurrent: Bool) -> some View {
        if isCurrent {
            ProgressView()
                .controlSize(.mini)
        } else {
            switch step {
            case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .cancelled: Image(systemName: "stop.circle").foregroundStyle(.secondary)
            default: Image(systemName: "checkmark.circle").foregroundStyle(.green)
            }
        }
    }

    static func title(_ step: ScenarioStep) -> String {
        switch step {
        case .waitingForCard: "Waiting for card"
        case .cardDetected: "Card detected"
        case .pinVerified: "PIN accepted"
        case let .executing(label): label
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}
