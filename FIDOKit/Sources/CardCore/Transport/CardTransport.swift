import Foundation

/// A physical link to a card.
///
/// The transport itself takes the timestamps in `CardConnection` and `RawExchange`, as close to the
/// hardware call as possible, so actor hops and decorators never end up inside an RTT.
public protocol CardTransport: AnyObject, Sendable {
    var kind: TransportKind { get }
    /// Starts a session and suspends until a card is connected.
    func open(prompt: String) async throws -> CardConnection
    /// Sends exactly one physical APDU. No chaining here.
    func transmit(_ command: Data) async throws -> RawExchange
    func close(errorMessage: String?) async
}
