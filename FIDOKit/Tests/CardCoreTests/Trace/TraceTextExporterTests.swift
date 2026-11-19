import CardCore
import Testing

@Suite("Text export")
struct TraceTextExporterTests {
    @Test("Matches the golden file", arguments: ["synthetic-fido2-getinfo-chained", "synthetic-select-fail", "synthetic-v2-timeline"])
    func golden(name: String) throws {
        let text = TraceTextExporter.text(for: try Fixtures.trace(name))
        #expect(text == (try Fixtures.golden(name)))
    }

    @Test("Sensitive exchanges are redacted by default")
    func redaction() throws {
        let trace = try TraceCodingTests.traceWithSensitiveExchange()

        let redacted = TraceTextExporter.text(for: trace)
        #expect(redacted.contains("TX <redacted 8 bytes>"))
        #expect(redacted.contains("RX <redacted 3 bytes> | SW 9000"))
        #expect(!redacted.contains("DE AD BE EF"))

        let plain = TraceTextExporter.text(for: trace, redactSensitive: false)
        #expect(plain.contains("TX 80 10 00 00 DE AD BE EF"))
    }

    @Test("A redacted trace stays redacted even when redaction is off")
    func alreadyRedacted() throws {
        let trace = try TraceCodingTests.traceWithSensitiveExchange().redactingSensitive()
        let text = TraceTextExporter.text(for: trace, redactSensitive: false)
        #expect(text.contains("TX <redacted 8 bytes>"))
    }
}
