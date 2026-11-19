import SwiftUI

@main
struct FIDOSimsApp: App {
    @State private var diagnostics = AppContainer().makeDiagnosticsViewModel()

    var body: some Scene {
        WindowGroup {
            DiagnosticsView(model: diagnostics)
        }
    }
}
