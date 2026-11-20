/// An error with the `sessionEnded.reason` it should be recorded with, when the default mapping is not
/// specific enough (e.g. `selectFailed`, `ctap1Only`).
struct ScenarioFailure: Error {
    let reason: SessionEndReason
    let underlying: any Error
}
