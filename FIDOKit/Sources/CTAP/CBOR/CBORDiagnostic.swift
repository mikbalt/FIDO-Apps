import CardCore
import Foundation

/// A plain-text dump of a CBOR value in RFC 8949 §8 diagnostic notation,
/// e.g. `{1: ["FIDO_2_0", "FIDO_2_1"], 3: h'2FC0579F…'}`.
public enum CBORDiagnostic {
    /// - Parameters:
    ///   - multiline: Puts each array element and map entry on its own indented line.
    ///   - maxBytes: Byte strings longer than this are cut and end with `…`. `nil` prints them in full.
    public static func format(_ value: CBORValue, multiline: Bool = false, maxBytes: Int? = nil) -> String {
        var printer = Printer(multiline: multiline, maxBytes: maxBytes)
        printer.write(value, indent: 0)
        return printer.output
    }

    private struct Printer {
        let multiline: Bool
        let maxBytes: Int?
        var output = ""

        mutating func write(_ value: CBORValue, indent: Int) {
            switch value {
            case let .unsigned(number):
                output += String(number)
            case let .negative(number):
                // −1 − n, printed without overflowing for n = 2⁶⁴ − 1.
                output += number == .max ? "-18446744073709551616" : "-\(number + 1)"
            case let .bytes(bytes):
                if let maxBytes, bytes.count > maxBytes {
                    output += "h'\(Hex.compact(bytes.prefix(maxBytes)))…'"
                } else {
                    output += "h'\(Hex.compact(bytes))'"
                }
            case let .text(text):
                output += quoted(text)
            case let .array(items):
                writeContainer(open: "[", close: "]", count: items.count, indent: indent) { printer, index, indent in
                    printer.write(items[index], indent: indent)
                }
            case let .map(entries):
                writeContainer(open: "{", close: "}", count: entries.count, indent: indent) { printer, index, indent in
                    let entry = entries[index]
                    printer.write(entry.key, indent: indent)
                    printer.output += ": "
                    printer.write(entry.value, indent: indent)
                }
            case let .bool(flag):
                output += flag ? "true" : "false"
            case .null:
                output += "null"
            }
        }

        private mutating func writeContainer(
            open: String, close: String, count: Int, indent: Int,
            element: (inout Printer, Int, Int) -> Void
        ) {
            output += open
            guard count > 0 else {
                output += close
                return
            }
            for index in 0..<count {
                if multiline {
                    output += "\n" + String(repeating: "  ", count: indent + 1)
                } else if index > 0 {
                    output += " "
                }
                element(&self, index, indent + 1)
                if index < count - 1 {
                    output += ","
                }
            }
            if multiline {
                output += "\n" + String(repeating: "  ", count: indent)
            }
            output += close
        }

        private func quoted(_ text: String) -> String {
            var result = "\""
            for scalar in text.unicodeScalars {
                switch scalar {
                case "\"": result += "\\\""
                case "\\": result += "\\\\"
                case "\n": result += "\\n"
                case "\r": result += "\\r"
                case "\t": result += "\\t"
                case _ where scalar.value < 0x20:
                    result += String(format: "\\u%04x", scalar.value)
                default:
                    result.unicodeScalars.append(scalar)
                }
            }
            return result + "\""
        }
    }
}
