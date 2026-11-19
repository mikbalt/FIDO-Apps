import FIDOKit
import SwiftUI

/// Share a trace as JSON or as the text log.
struct TraceShareMenu: View {
    let trace: Trace

    var body: some View {
        Menu {
            ShareLink(
                item: JSONTraceExport(trace: trace),
                preview: SharePreview("Trace \(trace.card.label) (JSON)")
            ) {
                Label("Export JSON", systemImage: "curlybraces")
            }
            ShareLink(
                item: TextTraceExport(trace: trace),
                preview: SharePreview("Trace \(trace.card.label) (text)")
            ) {
                Label("Export Text Log", systemImage: "doc.plaintext")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
}
