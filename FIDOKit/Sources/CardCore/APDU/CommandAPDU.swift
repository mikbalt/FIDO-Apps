import Foundation

/// An ISO 7816-4 command APDU, independent of its length encoding.
public struct CommandAPDU: Equatable, Sendable {
    public var cla: UInt8
    public var ins: UInt8
    public var p1: UInt8
    public var p2: UInt8
    public var data: Data
    /// Expected response length. `nil` means Le is absent; otherwise 1…65536.
    public var le: Int?

    public init(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: Data = Data(), le: Int? = nil) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.le = le
    }

    /// Encodes the command, covering ISO 7816-4 cases 1–4.
    ///
    /// - Short: `CLA INS P1 P2 [Lc data] [Le]`, with Le 256 encoded as `00`.
    /// - Extended: `CLA INS P1 P2 [00 Lc1 Lc2 data] [Le1 Le2]`; case 2 is `00 Le1 Le2`,
    ///   and Le 65536 is encoded as `00 00`.
    public func encoded(_ form: LengthForm) throws -> Data {
        if data.count > form.maxLc {
            throw APDUError.dataTooLong(count: data.count, form: form)
        }
        if let le, !(1...form.maxLe).contains(le) {
            throw APDUError.leOutOfRange(le: le, form: form)
        }

        var bytes = Data([cla, ins, p1, p2])
        switch form {
        case .short:
            if !data.isEmpty {
                bytes.append(UInt8(data.count))
                bytes.append(data)
            }
            if let le {
                bytes.append(UInt8(truncatingIfNeeded: le)) // 256 → 00
            }
        case .extended:
            if !data.isEmpty {
                bytes.append(0x00)
                bytes.append(contentsOf: Self.twoBytes(data.count))
                bytes.append(data)
            }
            if let le {
                if data.isEmpty {
                    bytes.append(0x00) // case 2E: 00 Le1 Le2
                }
                bytes.append(contentsOf: Self.twoBytes(le)) // 65536 → 00 00
            }
        }
        return bytes
    }

    private static func twoBytes(_ value: Int) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }
}
