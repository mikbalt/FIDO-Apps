import CardCore
import Foundation

/// Turns a trace's physical exchanges back into logical commands with their CBOR, for display.
///
/// Sensitive commands are never decoded: their payloads stay redacted in every view.
public enum TraceCommandDecoder {
    public static func commands(in trace: Trace) -> [DecodedCommand] {
        let grouped = Dictionary(grouping: trace.exchanges, by: \.commandIndex)
        return grouped.keys.sorted().compactMap { index in
            guard let exchanges = grouped[index], let last = exchanges.last else { return nil }
            return decode(exchanges, last: last)
        }
    }

    /// The decoded GetInfo of the trace's `GET_INFO` command, if it succeeded.
    public static func getInfo(in trace: Trace) -> AuthenticatorInfo? {
        commands(in: trace).first { $0.label == "GET_INFO" && $0.succeeded }?.response.flatMap {
            try? AuthenticatorInfo(cbor: $0)
        }
    }

    private static func decode(_ exchanges: [ExchangeEvent], last: ExchangeEvent) -> DecodedCommand {
        let sensitive = exchanges.contains(where: \.sensitive)
        let requestBytes = exchanges.compactMap { nfcctapData($0.tx) }.reduce(Data(), +)
        let isCTAP = !requestBytes.isEmpty
        // Response data: every 61xx part plus the final response; 9100 status updates are not data.
        let responseBytes = exchanges.filter { $0.sw.sw1 == 0x61 || $0.index == last.index }.reduce(Data()) { $0 + $1.rx }

        var request: CBORValue?
        var response: CBORValue?
        if isCTAP, !sensitive {
            request = requestBytes.count > 1 ? try? CBORDecoder.decodeExactly(requestBytes.dropFirst()).value : nil
            if last.sw.isSuccess, responseBytes.first == 0x00, responseBytes.count > 1 {
                response = try? CBORDecoder.decodeExactly(responseBytes.dropFirst()).value
            }
        }

        return DecodedCommand(
            commandIndex: last.commandIndex, label: last.label, sw: last.sw, ctapStatus: last.ctapStatus,
            sensitive: sensitive,
            summary: summary(label: last.label, sw: last.sw, ctapStatus: last.ctapStatus, rx: responseBytes, response: response),
            request: request, response: response
        )
    }

    private static func summary(label: String, sw: StatusWord, ctapStatus: UInt8?, rx: Data, response: CBORValue?) -> String {
        if let ctapStatus, ctapStatus != 0 {
            return "Refused: \(CTAPStatusCode.name(ctapStatus))"
        }
        guard sw.isSuccess else {
            return "SW \(sw.hex)" + (sw.displayName.map { " \($0)" } ?? "")
        }
        switch label {
        case "SELECT_FIDO": return "FIDO applet selected (\(String(decoding: rx, as: UTF8.self)))"
        case "GET_INFO": return "Capabilities received"
        case "CLIENT_PIN_RETRIES": return response?[3]?.intValue.map { "PIN retries: \($0)" } ?? "PIN retries received"
        case "CLIENT_PIN_KEY_AGREEMENT": return "Card key received"
        case "CLIENT_PIN_SET": return "PIN set"
        case "CLIENT_PIN_CHANGE": return "PIN changed"
        case "CLIENT_PIN_TOKEN": return "Token received"
        case "RESET": return "Card reset"
        default: return "Done"
        }
    }

    /// The data field of an NFCCTAP_MSG APDU (CLA `80` or chained `90`, INS `10`), short or extended.
    static func nfcctapData(_ tx: Data) -> Data? {
        let bytes = [UInt8](tx)
        guard bytes.count > 5, bytes[0] & 0xEF == 0x80, bytes[1] == 0x10 else { return nil }
        if bytes[4] != 0 {
            let length = Int(bytes[4])
            guard bytes.count >= 5 + length else { return nil }
            return Data(bytes[5..<(5 + length)])
        }
        guard bytes.count >= 7 else { return nil }
        let length = Int(bytes[5]) << 8 | Int(bytes[6])
        guard bytes.count >= 7 + length else { return nil }
        return Data(bytes[7..<(7 + length)])
    }
}
