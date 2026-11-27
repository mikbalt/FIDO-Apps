import Foundation

/// The SDK facade: every scenario the app runs, each with its full timing trace. [CONTRACT]
///
/// Scenarios never throw. Each one opens the transport, runs its commands and closes it; the result always
/// carries the trace, complete up to the failure point. Task cancellation gives the outcome `cancelled`.
public final class FIDOSimulator: Sendable {
    public static let prompt = "Hold the card near the top of the iPhone"

    private let transport: any CardTransport
    let configuration: FIDOSimConfiguration

    public init(transport: any CardTransport, configuration: FIDOSimConfiguration) {
        self.transport = transport
        self.configuration = configuration
    }

    /// `SELECT_FIDO` → `GET_INFO`.
    public func diagnostics(
        progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> ScenarioResult<AuthenticatorInfo> {
        await run(.diagnostics, cardLabel: configuration.cardLabel, progress: progress) { context in
            try await context.selectFIDO()
            return try await context.getInfo()
        }
    }

    /// `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_SET`.
    /// Fails early, before any ClientPIN command, if GetInfo shows a PIN is already set.
    public func setPIN(
        _ pin: String, cardLabel: String, progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> ScenarioResult<Void> {
        await run(.setPIN, cardLabel: cardLabel, progress: progress, validate: { _ = try CardPIN(pin) }) { context in
            try await context.selectFIDO()
            let info = try await context.getInfo()
            try Self.requirePinProtocol2(info)
            guard !info.isPINSet else { throw PINError.pinAlreadySet }
            let newPIN = try CardPIN(pin, minimumLength: info.minPINLength)
            let agreement = try await context.execute("CLIENT_PIN_KEY_AGREEMENT") { try await context.clientPIN.keyAgreement() }
            try await context.execute("CLIENT_PIN_SET") { try await context.clientPIN.setPIN(newPIN, using: agreement) }
            context.progress(.pinVerified)
        }
    }

    /// `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_RETRIES` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_CHANGE`.
    public func changePIN(
        current: String, new: String, cardLabel: String, progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> ScenarioResult<Void> {
        await run(.changePIN, cardLabel: cardLabel, progress: progress, validate: {
            _ = try CardPIN(current)
            _ = try CardPIN(new)
        }) { context in
            try await context.selectFIDO()
            let info = try await context.getInfo()
            try Self.requirePinProtocol2(info)
            // The current PIN was accepted by the card when it was set, so only the basic rules apply to it.
            let currentPIN = try CardPIN(current)
            let newPIN = try CardPIN(new, minimumLength: info.minPINLength)
            _ = try await context.execute("CLIENT_PIN_RETRIES") { try await context.clientPIN.getPINRetries() }
            let agreement = try await context.execute("CLIENT_PIN_KEY_AGREEMENT") { try await context.clientPIN.keyAgreement() }
            try await context.execute("CLIENT_PIN_CHANGE") {
                try await context.clientPIN.changePIN(current: currentPIN, new: newPIN, using: agreement)
            }
            context.progress(.pinVerified)
        }
    }

    /// `SELECT_FIDO` → `RESET`, with no GetInfo in between: the card accepts reset only within about 10 s of
    /// entering the field. On success the card's stored PIN is deleted and `onCardReset` is called.
    public func reset(
        confirmedCardLabel: String, progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> ScenarioResult<Void> {
        let configuration = configuration
        return await run(.reset, cardLabel: confirmedCardLabel, progress: progress) { context in
            try await context.selectFIDO()
            do {
                _ = try await context.execute("RESET") {
                    try await context.client.send(.reset, parameters: nil, label: "RESET")
                }
            } catch var error as CTAPError where error.code == CTAPError.notAllowed {
                error.detail = "Reset must happen within 10 s of tapping, or this card does not allow reset over NFC."
                throw error
            }
            try? configuration.pinStore?.deletePIN(for: confirmedCardLabel)
            configuration.onCardReset(confirmedCardLabel)
        }
    }

    // MARK: - Running a scenario

    static func requirePinProtocol2(_ info: AuthenticatorInfo) throws {
        guard info.supportsClientPIN else { throw PINError.clientPINUnsupported }
        // Brief 02 §2: a protocol-1-only card is a stop-and-ask, not something to work around.
        guard info.supportsPinProtocol2 else { throw PINError.pinProtocol2Unsupported(listed: info.pinUvAuthProtocols) }
    }

    func run<Value: Sendable>(
        _ scenario: TraceScenario,
        cardLabel: String,
        progress: @escaping @Sendable (ScenarioStep) -> Void,
        validate: () throws -> Void = {},
        body: (ScenarioContext) async throws -> Value
    ) async -> ScenarioResult<Value> {
        await run(scenario, cardLabel: cardLabel, progress: progress, validate: validate, body: body, finalize: { value, _ in value })
    }

    /// Runs `body` with the card, closes the session, then runs `finalize` (RP checks and storing) before the
    /// scenario reports `completed`. `finalize` only runs after a successful `body`; its time is not part of
    /// the trace.
    func run<Raw: Sendable, Value: Sendable>(
        _ scenario: TraceScenario,
        cardLabel: String,
        progress: @escaping @Sendable (ScenarioStep) -> Void,
        validate: () throws -> Void = {},
        body: (ScenarioContext) async throws -> Raw,
        finalize: (Raw, _ progress: @Sendable (ScenarioStep) -> Void) async -> Value
    ) async -> ScenarioResult<Value> {
        let metadata = TraceMetadata(
            app: configuration.app, transport: transport.kind, device: configuration.device,
            scenario: scenario, cardLabel: cardLabel, options: configuration.channelOptions.traceOptions
        )

        // Input checks come first: nothing is sent to the card for an invalid PIN.
        do {
            try validate()
        } catch {
            progress(.failed)
            return unconnected(metadata, reason: .error, error: error)
        }

        progress(.waitingForCard)
        let connection: CardConnection
        do {
            connection = try await transport.open(prompt: Self.prompt)
        } catch {
            let (reason, outcome) = Self.classify(error)
            progress(outcome.status == .cancelled ? .cancelled : .failed)
            return unconnected(metadata, reason: reason, error: error)
        }
        progress(.cardDetected)

        let recorder = TraceRecorder(metadata: metadata, connection: connection)
        let channel = ISO7816Channel(transport: transport, recorder: recorder, options: configuration.channelOptions)
        let client = CTAPClient(channel: channel)
        let context = ScenarioContext(
            channel: channel, client: client,
            clientPIN: ClientPIN(client: client, pinProtocol: PinProtocolTwo(randomness: configuration.pinRandomness)),
            progress: progress
        )

        do {
            let value = try await body(context)
            await transport.close(errorMessage: nil)
            await recorder.end(reason: .completed)
            await recorder.finish(.success)
            let final = await finalize(value, progress)
            progress(.completed)
            return ScenarioResult(value: final, error: nil, trace: await recorder.trace)
        } catch {
            let (reason, outcome) = Self.classify(error)
            await transport.close(errorMessage: outcome.status == .failure ? outcome.error?.message : nil)
            await recorder.end(reason: reason)
            await recorder.finish(outcome)
            progress(outcome.status == .cancelled ? .cancelled : .failed)
            return ScenarioResult(value: nil, error: outcome.error.map(FIDOSimError.init), trace: await recorder.trace)
        }
    }

    /// A trace for a scenario that never reached a card: no session events, just how it ended.
    private func unconnected<Value>(_ metadata: TraceMetadata, reason: SessionEndReason, error: any Error) -> ScenarioResult<Value> {
        let outcome = Self.classify(error).outcome
        let trace = Trace(
            id: metadata.id, createdAt: metadata.createdAt, app: metadata.app, transport: metadata.transport,
            device: metadata.device, scenario: metadata.scenario, outcome: outcome,
            card: CardInfo(label: metadata.cardLabel, initialSelectedAID: nil),
            options: metadata.options, events: [.sessionEnded(t: 0, reason: reason)]
        )
        return ScenarioResult(value: nil, error: outcome.error.map(FIDOSimError.init), trace: trace)
    }

    /// The `sessionEnded.reason` and `outcome` for an error (docs/trace-format.md).
    static func classify(_ error: any Error) -> (reason: SessionEndReason, outcome: TraceOutcome) {
        if let failure = error as? ScenarioFailure {
            return (failure.reason, Self.classify(failure.underlying).outcome)
        }
        switch error {
        case is CancellationError:
            return (.cancelled, .cancelled)
        case CardError.userCancelled:
            return (.userCancelled, .cancelled)
        case let cardError as CardError:
            return (SessionEndReason(cardError), .failure(TraceError(cardError)))
        case is CTAPError, is PINError:
            // The card session worked; the card or the PIN rules refused the request.
            return (.completed, .failure(TraceError(error)))
        default:
            return (.error, .failure(TraceError(error)))
        }
    }
}
