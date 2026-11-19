import FIDOKit
import Foundation

/// Fixtures live once, in CardCoreTests/Fixtures; FIDOKitTests read them from the source tree.
enum FixtureFiles {
    static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "CardCoreTests/Fixtures")

    static func trace(_ name: String, subdirectory: String = "synthetic") throws -> Trace {
        try Trace(jsonData: Data(contentsOf: directory.appending(path: "\(subdirectory)/\(name).json")))
    }
}
