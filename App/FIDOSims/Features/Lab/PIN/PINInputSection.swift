import SwiftUI

/// A PIN input: default, custom or stored.
struct PINInputSection: View {
    let title: String
    @Binding var source: PINSource
    @Binding var custom: String
    let sources: [PINSource]
    let hasStoredPIN: Bool

    var body: some View {
        Picker(title, selection: $source) {
            ForEach(sources) { source in
                Text(source.title).tag(source)
            }
        }
        if source == .custom {
            SecureField("\(title) (custom)", text: $custom)
                .textContentType(.oneTimeCode)
                .keyboardType(.asciiCapable)
                .accessibilityLabel("\(title), custom")
        } else if source == .stored, !hasStoredPIN {
            Text("No stored PIN for this card label.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
