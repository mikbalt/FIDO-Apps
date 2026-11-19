import FIDOKit

enum DiagnosticsRunState: Equatable {
    case idle
    case waitingForCard
    case exchanging(label: String)
    case done(SessionEndReason)
    case cancelled
    case failed(message: String)

    var isRunning: Bool {
        switch self {
        case .waitingForCard, .exchanging: true
        case .idle, .done, .cancelled, .failed: false
        }
    }
}
