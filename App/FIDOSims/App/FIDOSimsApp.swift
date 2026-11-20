import SwiftUI

@main
struct FIDOSimsApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            LabView(environment: container.environment)
        }
    }
}
