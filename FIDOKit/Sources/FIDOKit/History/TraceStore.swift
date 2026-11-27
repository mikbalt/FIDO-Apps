import Foundation

/// Every scenario run's trace, one JSON file per run in a directory (`<trace id>.json`).
///
/// Traces are saved with their sensitive exchanges redacted, so a PIN-carrying exchange never reaches the
/// disk in the clear; the Hex view of an old run therefore shows lengths for those exchanges.
public struct TraceStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/FIDOSims/History`.
    public static func defaultDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "FIDOSims", directoryHint: .isDirectory)
            .appending(path: "History", directoryHint: .isDirectory)
    }

    public func save(_ trace: Trace) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try trace.jsonData(redactSensitive: true).write(to: fileURL(trace.id), options: .atomic)
    }

    /// Newest first. Trace times have whole-second precision, so runs within one second are ordered by when
    /// their file was written. Files that cannot be read as a trace are skipped, not deleted.
    public func list() -> [Trace] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        let runs: [(trace: Trace, written: Date)] = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let trace = try? Trace(jsonData: Data(contentsOf: url)) else { return nil }
                let written = (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                return (trace, written)
            }
        return runs
            .sorted { ($0.trace.createdAt, $0.written) > ($1.trace.createdAt, $1.written) }
            .map(\.trace)
    }

    public func delete(id: UUID) throws {
        try FileManager.default.removeItem(at: fileURL(id))
    }

    private func fileURL(_ id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }
}
