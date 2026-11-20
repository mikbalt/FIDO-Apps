/// Where the app keeps card PINs when the tester turns "Store PIN" on. PINs are never logged.
public protocol PINStore: Sendable {
    func savePIN(_ pin: String, for cardLabel: String) throws
    func loadPIN(for cardLabel: String) throws -> String?
    func deletePIN(for cardLabel: String) throws
}
