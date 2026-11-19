import FIDOKit
import Foundation

/// A trace bundled under `MockTraces/`, replayable by `MockTransport`.
struct MockFixture: Identifiable, Equatable, Sendable {
    /// File name without extension.
    let id: String
    let trace: Trace

    /// Short name for pickers, e.g. `fido2-getinfo-chained`.
    var title: String {
        id.hasPrefix("synthetic-") ? String(id.dropFirst("synthetic-".count)) : id
    }

    /// Fixtures that fail to decode are skipped; they are covered by the package tests.
    static func loadAll(from bundle: Bundle) -> [MockFixture] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "MockTraces") ?? []
        return urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url), let trace = try? Trace(jsonData: data) else { return nil }
                return MockFixture(id: url.deletingPathExtension().lastPathComponent, trace: trace)
            }
    }
}
