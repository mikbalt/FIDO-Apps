import CardCore
import Foundation

/// The shared trace fixtures in `CardCoreTests/Fixtures`, read from the source tree.
enum CTAPFixtures {
    static let traceDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "CardCoreTests/Fixtures")

    static func trace(_ name: String, subdirectory: String = "synthetic") throws -> Trace {
        try Trace(jsonData: Data(contentsOf: traceDirectory.appending(path: "\(subdirectory)/\(name).json")))
    }
}
