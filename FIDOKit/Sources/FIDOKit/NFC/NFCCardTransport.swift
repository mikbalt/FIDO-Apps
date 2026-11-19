#if os(iOS)
@preconcurrency import CoreNFC
import Foundation

/// `CardTransport` over CoreNFC: an `NFCTagReaderSession` polling ISO 14443 for an ISO 7816 tag.
///
/// Timestamps are taken right around `sendCommand(apdu:)`: `startedAt` just before the call on the
/// session queue, `endedAt` as the first statement of its completion handler.
///
/// `@unchecked Sendable` invariant: every mutable stored property is read and written only on `queue`,
/// which is also the delegate queue of the reader session. Public entry points hop onto `queue` before
/// touching state; delegate callbacks already arrive on it.
public final class NFCCardTransport: NSObject, CardTransport, @unchecked Sendable {
    public let kind: TransportKind = .nfc

    /// Whether this device can read NFC tags.
    public static var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    private let queue = DispatchQueue(label: "FIDOKit.NFCCardTransport")
    private let clock = ContinuousClock()

    // Confined to `queue`.
    private var session: NFCTagReaderSession?
    /// Incremented per session, so delayed work can tell whether its session is still current.
    private var generation = 0
    private var detectedTag: (any NFCISO7816Tag)?
    private var tag: (any NFCISO7816Tag)?
    private var prompt = ""
    private var sessionStartedAt: ContinuousClock.Instant?
    private var pendingOpen: PendingOpen?
    private var invalidationError: CardError?

    /// One `open` call. Identity lets a late cancellation tell whether it still applies.
    /// `@unchecked Sendable`: like the transport, its state is only touched on `queue`.
    private final class PendingOpen: @unchecked Sendable {
        var continuation: CheckedContinuation<CardConnection, any Error>?
        var isCancelled = false
    }

    override public init() {
        super.init()
    }

    // MARK: - CardTransport

    public func open(prompt: String) async throws -> CardConnection {
        guard Self.isAvailable else { throw CardError.nfcUnavailable }
        let attempt = PendingOpen()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    self.begin(attempt, prompt: prompt, continuation: continuation)
                }
            }
        } onCancel: {
            queue.async {
                self.cancel(attempt)
            }
        }
    }

    public func transmit(_ command: Data) async throws -> RawExchange {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let apdu = NFCISO7816APDU(data: command) else {
                    continuation.resume(throwing: CardError.invalidAPDU)
                    return
                }
                if let error = self.invalidationError {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tag = self.tag else {
                    continuation.resume(throwing: CardError.notConnected)
                    return
                }
                let clock = self.clock
                let startedAt = clock.now
                tag.sendCommand(apdu: apdu) { data, sw1, sw2, error in
                    let endedAt = clock.now
                    if let error {
                        continuation.resume(throwing: Self.cardError(from: error))
                        return
                    }
                    continuation.resume(returning: RawExchange(
                        command: command,
                        response: ResponseAPDU(data: data, sw: StatusWord(sw1: sw1, sw2: sw2)),
                        startedAt: startedAt,
                        endedAt: endedAt
                    ))
                }
            }
        }
    }

    public func close(errorMessage: String?) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if let session = self.session {
                    if let errorMessage {
                        session.invalidate(errorMessage: errorMessage)
                    } else {
                        session.alertMessage = "Done"
                        session.invalidate()
                    }
                }
                self.resetSession()
                continuation.resume()
            }
        }
    }

    // MARK: - Session lifecycle (on `queue`)

    private func begin(
        _ attempt: PendingOpen, prompt: String, continuation: CheckedContinuation<CardConnection, any Error>
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        if attempt.isCancelled {
            continuation.resume(throwing: CancellationError())
            return
        }
        // A previous session that was never closed would keep the system reader busy.
        session?.invalidate()
        resetSession()

        guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: queue) else {
            continuation.resume(throwing: CardError.nfcUnavailable)
            return
        }
        generation += 1
        session.alertMessage = prompt
        attempt.continuation = continuation
        self.session = session
        self.prompt = prompt
        self.pendingOpen = attempt
        self.invalidationError = nil
        self.sessionStartedAt = clock.now
        session.begin()
    }

    private func cancel(_ attempt: PendingOpen) {
        dispatchPrecondition(condition: .onQueue(queue))
        attempt.isCancelled = true
        guard pendingOpen === attempt, let continuation = attempt.continuation else { return }
        attempt.continuation = nil
        session?.invalidate()
        resetSession()
        continuation.resume(throwing: CancellationError())
    }

    private func resetSession() {
        session = nil
        detectedTag = nil
        tag = nil
        pendingOpen = nil
        sessionStartedAt = nil
    }

    private func finishOpen(with result: Result<CardConnection, CardError>) {
        guard let attempt = pendingOpen, let continuation = attempt.continuation else { return }
        attempt.continuation = nil
        pendingOpen = nil
        continuation.resume(with: result.mapError { $0 as any Error })
    }

    private func restartPolling(message: String) {
        session?.alertMessage = message
        detectedTag = nil
        let generation = self.generation
        queue.asyncAfter(deadline: .now() + .milliseconds(800)) {
            guard generation == self.generation, let session = self.session else { return }
            session.alertMessage = self.prompt
            session.restartPolling()
        }
    }

    private func didConnect(error: (any Error)?, at connectedAt: ContinuousClock.Instant, generation: Int) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard generation == self.generation, let session, let isoTag = detectedTag else { return }
        if let error {
            restartPolling(message: "Connection failed: \(error.localizedDescription)")
            return
        }
        guard let startedAt = sessionStartedAt else { return }
        tag = isoTag
        session.alertMessage = "Reading…"
        finishOpen(with: .success(CardConnection(
            sessionStartedAt: startedAt,
            cardDetectedAt: connectedAt,
            initialSelectedAID: try? Hex.parse(isoTag.initialSelectedAID)
        )))
    }

    private static func cardError(from error: any Error) -> CardError {
        if let error = error as? CardError { return error }
        guard let error = error as? NFCReaderError else { return .underlying(error) }
        switch error.code {
        case .readerSessionInvalidationErrorUserCanceled:
            return .userCancelled
        case .readerSessionInvalidationErrorSessionTimeout:
            return .sessionTimeout
        case .readerTransceiveErrorTagConnectionLost, .readerTransceiveErrorTagNotConnected:
            return .tagConnectionLost
        case .readerErrorUnsupportedFeature, .readerErrorRadioDisabled:
            return .nfcUnavailable
        default:
            return .underlying(error)
        }
    }
}

// MARK: - NFCTagReaderSessionDelegate (called on `queue`)

extension NFCCardTransport: NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) {
        dispatchPrecondition(condition: .onQueue(queue))
        // Invalidations of sessions we already closed or replaced are expected; ignore them.
        guard session === self.session else { return }
        let cardError = Self.cardError(from: error)
        invalidationError = cardError
        finishOpen(with: .failure(cardError))
        resetSession()
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard session === self.session else { return }

        if tags.count > 1 {
            restartPolling(message: "More than one card detected. Present a single card.")
            return
        }
        guard let detected = tags.first, case let .iso7816(isoTag) = detected else {
            restartPolling(message: "This card is not supported. Try another card.")
            return
        }

        detectedTag = isoTag
        let generation = self.generation
        session.connect(to: detected) { error in
            let connectedAt = self.clock.now
            self.queue.async {
                self.didConnect(error: error, at: connectedAt, generation: generation)
            }
        }
    }
}
#endif
