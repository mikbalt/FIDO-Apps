import Foundation

public enum ChannelError: Error, Equatable, Sendable {
    /// An intermediate chunk of a chained command was not answered with `9000`.
    case chainingFailed(chunk: Int, sw: StatusWord)
    /// The card kept answering `9100` for longer than `ChannelOptions.statusUpdateTimeout`.
    case statusUpdateTimeout
    /// A command finished with a status word the caller cannot continue from.
    case unexpectedStatus(StatusWord)
    /// SELECT succeeded but returned an unknown version string.
    case unknownAppletVersion(String)
}

extension ChannelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .chainingFailed(chunk, sw):
            "Chained command failed at chunk \(chunk) with SW \(sw)."
        case .statusUpdateTimeout:
            "The card did not finish processing in time."
        case let .unexpectedStatus(sw):
            "The card answered with SW \(sw)."
        case let .unknownAppletVersion(version):
            "SELECT returned an unknown FIDO version \"\(version)\"."
        }
    }
}
