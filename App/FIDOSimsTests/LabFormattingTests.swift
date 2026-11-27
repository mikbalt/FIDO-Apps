import CTAP
import Testing
@testable import FIDOSims

@MainActor
@Suite("Lab formatting")
struct LabFormattingTests {
    @Test("Elapsed time always uses a '.' decimal and one fraction digit")
    func elapsed() {
        #expect(ElapsedTimeView.format(0.3) == "0.3 s")
        #expect(ElapsedTimeView.format(12.34) == "12.3 s")
        #expect(ElapsedTimeView.format(-1) == "0.0 s")
        #expect(ElapsedTimeView.format(1.96) == "2.0 s")
    }

    @Test("GetInfo typed lists use the CBOR diagnostic style")
    func lists() {
        #expect(GetInfoTableView.list([.text("FIDO_2_0"), .text("FIDO_2_1")]) == "[\"FIDO_2_0\", \"FIDO_2_1\"]")
        #expect(GetInfoTableView.list([.unsigned(2)]) == "[2]")
        #expect(GetInfoTableView.list([]) == "—")
    }

    @Test("Exchanges caption names the command count")
    func caption() {
        #expect(MetricTilesView.caption(commands: 2) == "APDUs, 2 commands")
        #expect(MetricTilesView.caption(commands: 1) == "APDUs, 1 command")
    }
}
