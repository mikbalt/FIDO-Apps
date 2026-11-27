import FIDOKit
import Foundation
import os
import Testing
@testable import FIDOSims

/// A PIN store that lives in memory, so tests never touch the Keychain.
final class InMemoryPINStore: PINStore {
    private let pins = OSAllocatedUnfairLock<[String: String]>(initialState: [:])

    func savePIN(_ pin: String, for cardLabel: String) throws { pins.withLock { $0[cardLabel] = pin } }
    func loadPIN(for cardLabel: String) throws -> String? { pins.withLock { $0[cardLabel] } }
    func deletePIN(for cardLabel: String) throws { pins.withLock { $0[cardLabel] = nil } }
}

private final class BundleToken {}

enum TestSupport {
    /// The bundled synthetic MockTraces fixtures (the tests run inside the app).
    static func fixtures() -> [MockFixture] {
        MockFixture.loadAll(from: Bundle.main)
    }

    /// A fixture trace under a fresh id, with the given outcome. Stands in for one scenario run.
    static func trace(outcome: TraceOutcome = .success) throws -> Trace {
        var trace = try #require(fixtures().first?.trace)
        trace.id = UUID()
        trace.outcome = outcome
        return trace
    }

    /// An environment with NFC "available" whose transport is the given in-memory card; no NFC involved.
    @MainActor
    static func environment(
        nfc: Bool = true, card: (any CardTransport)? = nil, store: any PINStore = InMemoryPINStore(),
        credentials: CredentialStore = CredentialStore(),
        history: TraceStore = TraceStore(directory: FileManager.default.temporaryDirectory.appending(path: "fidosims-tests-\(UUID().uuidString)"))
    ) -> LabEnvironment {
        LabEnvironment(
            isNFCAvailable: nfc,
            fixtures: fixtures(),
            makeTransport: { _ in
                guard let card else { throw CardError.nfcUnavailable }
                return card
            },
            pinStore: store,
            credentialStore: credentials,
            traceStore: history,
            onCardReset: { label in _ = try? credentials.invalidateCredentials(forCard: label) }
        )
    }

    /// Waits (bounded) for a run to end.
    @MainActor
    static func waitUntilIdle(_ runner: ScenarioRunModel) async {
        for _ in 0..<2000 where runner.isRunning {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// Lets a test hold a run open until it releases it.
actor Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
