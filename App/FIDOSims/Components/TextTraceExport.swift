import CoreTransferable
import FIDOKit
import UniformTypeIdentifiers

/// A trace shared as the text log. Sensitive exchanges are always redacted.
struct TextTraceExport: Transferable {
    let trace: Trace

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { export in
            Data(TraceTextExporter.text(for: export.trace, redactSensitive: true).utf8)
        }
        .suggestedFileName { "fidosims-\($0.trace.id.uuidString).txt" }
    }
}
