/// Progress of a `FIDOSimulator` scenario. [CONTRACT]
public enum ScenarioStep: Sendable, Equatable {
    case waitingForCard, cardDetected, pinVerified, executing(String), completed, failed, cancelled
}
