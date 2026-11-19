import Foundation

/// A response APDU: optional data followed by the status word.
public struct ResponseAPDU: Equatable, Sendable {
    public var data: Data
    public var sw: StatusWord

    public init(data: Data = Data(), sw: StatusWord) {
        self.data = data
        self.sw = sw
    }

    /// Parses `data || SW1 SW2`.
    public init(raw: Data) throws {
        guard raw.count >= 2 else {
            throw APDUError.responseTooShort(count: raw.count)
        }
        let bytes = [UInt8](raw)
        self.data = Data(bytes.dropLast(2))
        self.sw = StatusWord(sw1: bytes[bytes.count - 2], sw2: bytes[bytes.count - 1])
    }

    /// `data || SW1 SW2`.
    public var raw: Data {
        data + [sw.sw1, sw.sw2]
    }
}
