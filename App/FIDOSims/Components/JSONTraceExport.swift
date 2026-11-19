import CoreTransferable
import FIDOKit
import UniformTypeIdentifiers

/// A trace shared as a JSON file. Sensitive exchanges are always redacted.
struct JSONTraceExport: Transferable {
    let trace: Trace

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            try export.trace.jsonData(redactSensitive: true)
        }
        .suggestedFileName { "fidosims-\($0.trace.id.uuidString).json" }
    }
}
