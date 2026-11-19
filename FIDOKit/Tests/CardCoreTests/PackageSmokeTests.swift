import Foundation
import Testing

@Suite("Package")
struct PackageSmokeTests {
    @Test("Fixtures are bundled as resources")
    func fixturesBundled() {
        #expect(Bundle.module.url(forResource: "Fixtures", withExtension: nil) != nil)
    }
}
