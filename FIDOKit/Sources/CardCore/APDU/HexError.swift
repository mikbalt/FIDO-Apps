import Foundation

public enum HexError: Error, Equatable, Sendable {
    case oddLength
    case invalidCharacter(Character)
}

extension HexError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .oddLength: "Hex string has an odd number of digits."
        case let .invalidCharacter(character): "Invalid hex character '\(character)'."
        }
    }
}
