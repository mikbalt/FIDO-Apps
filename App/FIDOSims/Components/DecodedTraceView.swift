import FIDOKit
import SwiftUI

/// The Decoded view: one line per command, the GetInfo table, and a CBOR dump per command.
/// Sensitive payloads are never decoded and show as "Payload redacted".
struct DecodedTraceView<Header: View>: View {
    let trace: Trace
    let header: Header

    var body: some View {
        let commands = TraceCommandDecoder.commands(in: trace)
        Section {
            ForEach(commands) { command in
                HStack(alignment: .firstTextBaseline) {
                    Text(command.commandIndex, format: .number.precision(.integerLength(2...)))
                        .foregroundStyle(.secondary)
                    Text(command.label)
                        .fontWeight(.semibold)
                    Text(command.summary)
                        .foregroundStyle(command.succeeded ? Color.primary : Color.orange)
                }
                .font(.caption.monospaced())
            }
        } header: {
            header
        }

        if let info = TraceCommandDecoder.getInfo(in: trace) {
            GetInfoTableView(info: info)
        }

        Section("CBOR") {
            ForEach(commands) { command in
                VStack(alignment: .leading, spacing: 4) {
                    Text(command.label)
                        .font(.caption.weight(.semibold))
                    if command.sensitive {
                        Text("Payload redacted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if command.request == nil, command.response == nil {
                        Text("No CBOR payload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        dump("Request", command.request)
                        dump("Response", command.response)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dump(_ title: String, _ value: CBORValue?) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CBORDiagnostic.format(value, multiline: true))
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }
        }
    }
}
