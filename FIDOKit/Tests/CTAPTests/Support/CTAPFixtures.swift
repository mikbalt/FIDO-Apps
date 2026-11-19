import CardCore
import Testing
import Foundation

/// Fixtures bundled with CTAPTests, plus the shared trace fixtures in CardCoreTests (read from the source tree).
enum CTAPFixtures {
    struct Vector: Decodable, Sendable, CustomTestStringConvertible {
        var name: String
        var hex: String
        var diag: String

        var testDescription: String { name }
    }

    static func url(_ path: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(path)", withExtension: nil) else {
            throw FixtureError.missing(path)
        }
        return url
    }

    static let cborVectors: [Vector] = {
        // A test failure, not a crash, if the file is missing: an empty list fails `vectorsPresent`.
        (try? JSONDecoder().decode([Vector].self, from: Data(contentsOf: url("vectors/cbor.json")))) ?? []
    }()

    /// `CardCoreTests/Fixtures`, the single copy of the trace fixtures.
    static let traceDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "CardCoreTests/Fixtures")

    static func trace(_ name: String, subdirectory: String = "synthetic") throws -> Trace {
        try Trace(jsonData: Data(contentsOf: traceDirectory.appending(path: "\(subdirectory)/\(name).json")))
    }

    /// Names (without `.json`) of the traces in `CardCoreTests/Fixtures/real`.
    static var realTraceNames: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: traceDirectory.appending(path: "real"), includingPropertiesForKeys: nil
        )) ?? []
        return files.filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
