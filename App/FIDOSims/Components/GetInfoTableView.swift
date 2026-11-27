import FIDOKit
import SwiftUI

/// The decoded GetInfo: typed fields, the options, then every other key the card sent.
struct GetInfoTableView: View {
    let info: AuthenticatorInfo

    var body: some View {
        Section("GetInfo") {
            row("versions", Self.list(info.versions.map(CBORValue.text)))
            row("aaguid", info.aaguid?.uuidString ?? "—")
            row("pinUvAuthProtocols", Self.list(info.pinUvAuthProtocols.map { CBORValue.unsigned(UInt64($0)) }))
            row("algorithms", Self.list(info.algorithms.map { CBORValue.text($0.name) }))
            row("maxMsgSize", info.maxMsgSize.map(String.init) ?? "— (1024)")
            row("maxCredentialCountInList", info.maxCredentialCountInList.map(String.init) ?? "—")
            row("minPINLength", "\(info.minPINLength)")
            row("firmwareVersion", info.firmwareVersion.map(String.init) ?? "—")
            row("remainingDiscoverableCredentials", info.remainingDiscoverableCredentials.map(String.init) ?? "—")
            ForEach(Array(info.options.raw.enumerated()), id: \.offset) { _, entry in
                row("options.\(entry.key.textValue ?? CBORDiagnostic.format(entry.key))", CBORDiagnostic.format(entry.value))
            }
            ForEach(Array(info.otherEntries.enumerated()), id: \.offset) { _, entry in
                row(AuthenticatorInfo.displayName(of: entry.key), CBORDiagnostic.format(entry.value, maxBytes: 32))
            }
        }
    }

    /// Typed lists use the same CBOR diagnostic style as the raw entries, e.g. `["FIDO_2_0", "FIDO_2_1"]`.
    static func list(_ items: [CBORValue]) -> String {
        items.isEmpty ? "—" : CBORDiagnostic.format(.array(items))
    }

    private func row(_ name: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Text(name)
                .font(.caption)
        }
    }
}
