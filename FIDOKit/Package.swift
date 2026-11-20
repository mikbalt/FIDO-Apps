// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FIDOKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FIDOKit", targets: ["FIDOKit"]),
    ],
    targets: [
        // Pure Swift: APDU model, ISO 7816 channel, transport contract, traces, mock transport.
        .target(name: "CardCore"),
        // Pure Swift: canonical CBOR, CTAP client, command models (GetInfo, ...).
        .target(name: "CTAP", dependencies: ["CardCore"]),
        // CoreNFC transport (iOS only) and diagnostics scenarios. Re-exports CardCore and CTAP.
        .target(name: "FIDOKit", dependencies: ["CardCore", "CTAP"]),
        .testTarget(
            name: "CardCoreTests",
            dependencies: ["CardCore"],
            resources: [.copy("Fixtures")]
        ),
        // Reads the shared trace fixtures from CardCoreTests/Fixtures via #filePath.
        .testTarget(name: "CTAPTests", dependencies: ["CTAP"]),
        // Loads fixtures from CardCoreTests/Fixtures via #filePath, so there is a single copy.
        .testTarget(name: "FIDOKitTests", dependencies: ["FIDOKit"]),
    ],
    swiftLanguageModes: [.v6]
)
