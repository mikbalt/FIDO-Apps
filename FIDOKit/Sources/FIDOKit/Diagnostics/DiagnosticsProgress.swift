/// Progress of a diagnostics run, for UI feedback.
public enum DiagnosticsProgress: Sendable, Equatable {
    case waitingForCard
    case cardDetected
    /// A logical command is about to be sent.
    case exchanging(label: String)
    /// The card answered `9100`; the user should keep the card in place.
    case statusUpdate(NFCCTAPStatus)
    case finished(SessionEndReason)
}
