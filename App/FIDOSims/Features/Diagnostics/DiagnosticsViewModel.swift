import FIDOKit
import Foundation
import Observation

/// Runs SELECT + GetInfo diagnostics and keeps the last traces in memory.
@MainActor
@Observable
final class DiagnosticsViewModel {
    static let historyLimit = 10

    // MARK: Controls

    var transportChoice: TransportChoice
    var selectedFixtureID: MockFixture.ID?
    var lengthForm: LengthForm = .short
    var cardLabel = "Lab card A"
    var realtimeReplay = false
    var displayMode: ExchangeDisplayMode = .safe

    let fixtures: [MockFixture]
    let isNFCAvailable: Bool

    // MARK: Run

    private(set) var state: DiagnosticsRunState = .idle
    private(set) var runStartedAt: Date?
    private(set) var runEndedAt: Date?
    /// Set while the card reports NFCCTAP status updates (SW 9100).
    private(set) var statusNote: String?

    // MARK: Results

    private(set) var history: [Trace] = [] {
        didSet { updateSelection() }
    }
    var selectedTraceID: Trace.ID? {
        didSet { updateSelection() }
    }
    /// The trace of the most recent run. `nil` while a run is in progress, or if it ended before a card
    /// connected (no trace).
    private(set) var latestTraceID: Trace.ID?
    /// Cached from `history` and `selectedTraceID`, so result views don't depend on the whole history.
    private(set) var selectedTrace: Trace?
    private(set) var selectedMetrics: TraceMetrics?

    private let makeTransport: (TransportSelection) throws -> any CardTransport
    private var runTask: Task<Void, Never>?

    init(
        fixtures: [MockFixture],
        isNFCAvailable: Bool,
        makeTransport: @escaping (TransportSelection) throws -> any CardTransport
    ) {
        self.fixtures = fixtures
        self.isNFCAvailable = isNFCAvailable
        self.makeTransport = makeTransport
        self.transportChoice = isNFCAvailable ? .nfc : .mock
        self.selectedFixtureID = fixtures.first?.id
    }

    /// Mock is the only option in the Simulator or without NFC hardware.
    var isMockForced: Bool { !isNFCAvailable }

    var selectedFixture: MockFixture? {
        fixtures.first { $0.id == selectedFixtureID }
    }

    var canRun: Bool {
        !state.isRunning && (transportChoice == .nfc || selectedFixture != nil)
    }

    /// The results on screen belong to a History trace, not to the most recent run.
    var isViewingHistory: Bool {
        selectedTrace != nil && selectedTraceID != latestTraceID
    }

    // MARK: Actions

    func run() {
        guard canRun else { return }
        // The previous results must not stay on screen next to the new run's state.
        latestTraceID = nil
        selectedTraceID = nil

        let selection: TransportSelection
        var options = DiagnosticsOptions(lengthForm: lengthForm, cardLabel: cardLabel)
        switch transportChoice {
        case .nfc:
            selection = .nfc
        case .mock:
            guard let fixture = selectedFixture else { return }
            selection = .mock(fixture, realtime: realtimeReplay)
            // A replay only matches when it sends the same bytes as the recording.
            options.lengthForm = fixture.trace.options.lengthForm
            options.getResponseSupported = fixture.trace.options.getResponseSupported
            if cardLabel.isEmpty {
                options.cardLabel = fixture.trace.card.label
            }
        }

        let transport: any CardTransport
        do {
            transport = try makeTransport(selection)
        } catch {
            state = .failed(message: error.localizedDescription)
            return
        }

        runStartedAt = .now
        runEndedAt = nil
        statusNote = nil
        state = .waitingForCard

        // Progress arrives off the main actor; a stream keeps it in order.
        let (progressUpdates, progressContinuation) = AsyncStream.makeStream(of: DiagnosticsProgress.self)
        Task {
            for await progress in progressUpdates {
                apply(progress)
            }
        }

        runTask = Task {
            defer { progressContinuation.finish() }
            do {
                let trace = try await FIDODiagnostics.runSelectAndGetInfo(
                    transport: transport,
                    options: options,
                    progress: { progressContinuation.yield($0) }
                )
                finish(with: trace, state: .done(trace.endReason ?? .completed))
            } catch let failure as DiagnosticsFailure {
                finish(
                    with: failure.trace,
                    state: failure.isCancellation ? .cancelled : .failed(message: failure.localizedDescription)
                )
            } catch is CancellationError {
                finish(with: nil, state: .cancelled)
            } catch CardError.userCancelled {
                finish(with: nil, state: .cancelled)
            } catch {
                finish(with: nil, state: .failed(message: error.localizedDescription))
            }
        }
    }

    func cancel() {
        runTask?.cancel()
    }

    /// Leaves History and shows the most recent run again.
    func showLatest() {
        selectedTraceID = latestTraceID
    }

    // MARK: Private

    private func apply(_ progress: DiagnosticsProgress) {
        // Late events from a finished run must not overwrite its final state.
        guard state.isRunning else { return }
        switch progress {
        case .waitingForCard:
            state = .waitingForCard
        case .cardDetected:
            state = .exchanging(label: "")
        case let .exchanging(label):
            state = .exchanging(label: label)
            statusNote = nil
        case let .statusUpdate(status):
            statusNote = status == .userPresenceNeeded
                ? "Touch the card if it asks for presence"
                : "Keep the card in place"
        case .finished:
            break
        }
    }

    private func finish(with trace: Trace?, state: DiagnosticsRunState) {
        runEndedAt = .now
        statusNote = nil
        self.state = state
        runTask = nil
        guard let trace else { return }
        history = Array(([trace] + history).prefix(Self.historyLimit))
        latestTraceID = trace.id
        selectedTraceID = trace.id
    }

    private func updateSelection() {
        let trace = history.first { $0.id == selectedTraceID }
        selectedTrace = trace
        selectedMetrics = trace.map(TraceMetrics.init(trace:))
    }
}
