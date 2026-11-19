import FIDOKit
import Testing

@Suite("FIDOKit package")
struct PackageSmokeTests {
    @Test("FIDOKit links")
    func links() {
        #expect(Bool(true))
    }
}
