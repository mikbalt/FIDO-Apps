import Foundation

extension Trace {
    /// Decodes a trace JSON document.
    public init(jsonData: Data) throws {
        self = try JSONDecoder().decode(Trace.self, from: jsonData)
    }

    /// The JSON export. Sensitive exchanges are redacted unless `redactSensitive` is false.
    public func jsonData(redactSensitive: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(redactSensitive ? redactingSensitive() : self)
    }
}
