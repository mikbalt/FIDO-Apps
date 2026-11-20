import SwiftUI

/// The setup footer of the PIN and reset screens.
struct PINScreenFooter: View {
    let needsNFC: Bool
    let setupError: String?
    let note: String

    var body: some View {
        if let setupError {
            Text(setupError).foregroundStyle(.red)
        } else if needsNFC {
            Text("Needs NFC and a real card; there is no mock for this scenario.")
        } else {
            Text(note)
        }
    }
}
