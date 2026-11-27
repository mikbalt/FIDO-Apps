import FIDOKit

/// Plain-text names for a trace, shared by the History rows and status.
enum TraceDescription {
    static func scenario(_ trace: Trace) -> String {
        switch trace.scenario {
        case .diagnostics: "Diagnostics"
        case .setPIN: "Set PIN"
        case .changePIN: "Change PIN"
        case .reset: "Reset"
        case .register: "Register"
        case .authenticate: "Authenticate"
        case let .unknown(raw)?: raw
        case nil: "Run"
        }
    }

    static func outcome(_ trace: Trace) -> String {
        trace.outcome.map { $0.error?.name ?? $0.status.rawValue.capitalized } ?? trace.endReason?.displayName ?? "In progress"
    }

    static func time(_ trace: Trace) -> String {
        trace.createdAt.formatted(date: .abbreviated, time: .standard)
    }
}
