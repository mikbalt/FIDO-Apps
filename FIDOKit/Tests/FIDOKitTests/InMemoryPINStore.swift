import FIDOKit
import os

final class InMemoryPINStore: PINStore {
    private let pins = OSAllocatedUnfairLock<[String: String]>(initialState: [:])

    func savePIN(_ pin: String, for cardLabel: String) throws { pins.withLock { $0[cardLabel] = pin } }
    func loadPIN(for cardLabel: String) throws -> String? { pins.withLock { $0[cardLabel] } }
    func deletePIN(for cardLabel: String) throws { pins.withLock { $0[cardLabel] = nil } }
}
