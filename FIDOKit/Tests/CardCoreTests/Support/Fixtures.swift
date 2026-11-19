import CardCore
import Foundation

/// Access to the bundled test fixtures.
enum Fixtures {
    static let synthetic = [
        "synthetic-fido2-getinfo-chained",
        "synthetic-u2f-only",
        "synthetic-select-fail",
    ]

    static func url(_ name: String, subdirectory: String = "synthetic", extension ext: String = "json") throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/\(subdirectory)") else {
            throw FixtureError.missing("\(subdirectory)/\(name).\(ext)")
        }
        return url
    }

    static func trace(_ name: String, subdirectory: String = "synthetic") throws -> Trace {
        try Trace(jsonData: Data(contentsOf: url(name, subdirectory: subdirectory)))
    }

    static func golden(_ name: String) throws -> String {
        try String(contentsOf: url(name, subdirectory: "golden", extension: "txt"), encoding: .utf8)
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
