import Testing
@testable import FIDOSims

@MainActor
@Suite("ResetViewModel")
struct ResetViewModelTests {
    @Test("Run is enabled only when the confirmation equals the card label")
    func confirmation() {
        let model = ResetViewModel(environment: TestSupport.environment())
        #expect(!model.canRun)

        model.confirmation = "Lab card"
        #expect(!model.canRun)
        model.confirmation = "lab card a"
        #expect(!model.canRun)
        model.confirmation = "Lab card A"
        #expect(model.isConfirmed)
        #expect(model.canRun)

        // Changing the label invalidates the confirmation.
        model.cardLabel = "Lab card B"
        #expect(!model.canRun)
        model.confirmation = "Lab card B"
        #expect(model.canRun)

        model.cardLabel = ""
        model.confirmation = ""
        #expect(!model.canRun)
    }

    @Test("Run needs NFC even when confirmed")
    func needsNFC() {
        let model = ResetViewModel(environment: TestSupport.environment(nfc: false))
        model.confirmation = model.cardLabel
        #expect(!model.canRun)
    }
}
